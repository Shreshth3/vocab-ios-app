//
//  FirestoreLogger.swift
//  study-vocab
//
//  Append-only logging service for user actions in Cloud Firestore
//

import Foundation
import FirebaseFirestore

/// Singleton service for logging user actions to Cloud Firestore as append-only logs
class FirestoreLogger {
    static let shared = FirestoreLogger()

    private let db = Firestore.firestore()
    private let sessionID: String

    private init() {
        // Generate a unique session ID when the logger is initialized
        self.sessionID = UUID().uuidString
        #if DEBUG
        print("[FirestoreLogger] Initialized with session ID: \(sessionID)")
        #endif
    }

    /// Log when user marks a card as correct
    func logCardCorrect(prompt: String, translation: String, currentIndex: Int, deckSize: Int, correctCount: Int, wrongCount: Int, mode: String) {
        logAction(
            type: "card_correct",
            cardPrompt: prompt,
            cardTranslation: translation,
            currentIndex: currentIndex,
            deckSize: deckSize,
            correctCount: correctCount,
            wrongCount: wrongCount,
            mode: mode
        )
    }

    /// Log when user marks a card as incorrect
    func logCardIncorrect(prompt: String, translation: String, currentIndex: Int, deckSize: Int, correctCount: Int, wrongCount: Int, mode: String) {
        logAction(
            type: "card_incorrect",
            cardPrompt: prompt,
            cardTranslation: translation,
            currentIndex: currentIndex,
            deckSize: deckSize,
            correctCount: correctCount,
            wrongCount: wrongCount,
            mode: mode
        )
    }

    /// Log when user undoes their last action
    func logUndo(currentIndex: Int, deckSize: Int, correctCount: Int, wrongCount: Int, mode: String) {
        logAction(
            type: "undo",
            currentIndex: currentIndex,
            deckSize: deckSize,
            correctCount: correctCount,
            wrongCount: wrongCount,
            mode: mode
        )
    }

    /// Log when user restarts the deck
    func logRestart(deckSize: Int, mode: String) {
        logAction(
            type: "restart",
            deckSize: deckSize,
            correctCount: 0,
            wrongCount: 0,
            mode: mode
        )
    }

    /// Log when user starts studying mistakes
    func logStudyMistakes(mistakeCount: Int, mode: String) {
        logAction(
            type: "study_mistakes",
            deckSize: mistakeCount,
            correctCount: 0,
            wrongCount: 0,
            mode: mode
        )
    }

    /// Log when user starts a new study session
    func logSessionStart(deckSize: Int, mode: String, deckName: String? = nil) {
        var data: [String: Any] = [
            "type": "session_start",
            "timestamp": Timestamp(date: Date()),
            "sessionID": sessionID,
            "deckSize": deckSize,
            "mode": mode
        ]

        if let name = deckName {
            data["deckName"] = name
        }

        writeLog(data: data)
    }

    /// Log when user completes a deck or ends a session
    func logSessionEnd(deckSize: Int, correctCount: Int, wrongCount: Int, completionRate: Double, mode: String) {
        logAction(
            type: "session_end",
            deckSize: deckSize,
            correctCount: correctCount,
            wrongCount: wrongCount,
            mode: mode,
            additionalData: ["completionRate": completionRate]
        )
    }

    /// Fetch review records for given card prompts from Firestore
    /// - Parameter prompts: Array of card prompts to query
    /// - Returns: Array of dictionaries containing the fetched review records
    func fetchReviewRecords(for prompts: [String]) async -> [[String: Any]] {
        guard !prompts.isEmpty else {
            #if DEBUG
            print("[FirestoreLogger] No prompts provided for fetch")
            #endif
            return []
        }

        var allResults: [[String: Any]] = []

        // Firestore's 'in' operator supports max 30 items, so batch the queries
        let batchSize = 30
        let batches = stride(from: 0, to: prompts.count, by: batchSize).map {
            Array(prompts[$0..<min($0 + batchSize, prompts.count)])
        }

        #if DEBUG
        print("[FirestoreLogger] Fetching review records for \(prompts.count) prompts in \(batches.count) batch(es)")

        // DEBUG: Test query without mode filter for first batch only
        if !batches.isEmpty {
            let firstBatch = batches[0]
            print("[FirestoreLogger] DEBUG - Testing first batch without mode filter...")
            print("[FirestoreLogger] DEBUG - First batch prompts: \(firstBatch)")
            do {
                let testQuery = try await db.collection("user_actions")
                    .whereField("cardPrompt", in: firstBatch)
                    .getDocuments()
                print("[FirestoreLogger] DEBUG - Found \(testQuery.documents.count) records WITHOUT mode filter")
                if !testQuery.documents.isEmpty {
                    let firstDoc = testQuery.documents[0].data()
                    print("[FirestoreLogger] DEBUG - First record mode: \(firstDoc["mode"] ?? "nil")")
                    print("[FirestoreLogger] DEBUG - First record cardPrompt: \(firstDoc["cardPrompt"] ?? "nil")")
                }
            } catch {
                print("[FirestoreLogger] DEBUG - Error in test query: \(error.localizedDescription)")
            }
        }
        #endif

        for (index, batch) in batches.enumerated() {
            do {
                let querySnapshot = try await db.collection("user_actions")
                    .whereField("mode", isEqualTo: "review")
                    .whereField("cardPrompt", in: batch)
                    .getDocuments()

                let batchResults = querySnapshot.documents.map { document in
                    var data = document.data()
                    data["documentID"] = document.documentID
                    return data
                }

                allResults.append(contentsOf: batchResults)

                #if DEBUG
                print("[FirestoreLogger] Batch \(index + 1)/\(batches.count): Fetched \(batchResults.count) records")
                #endif
            } catch {
                #if DEBUG
                print("[FirestoreLogger] Error fetching batch \(index + 1): \(error.localizedDescription)")
                #endif
            }
        }

        #if DEBUG
        print("[FirestoreLogger] Total records fetched: \(allResults.count)")
        #endif

        return allResults
    }

    // MARK: - Private Helper Methods

    private func logAction(
        type: String,
        cardPrompt: String? = nil,
        cardTranslation: String? = nil,
        currentIndex: Int? = nil,
        deckSize: Int,
        correctCount: Int,
        wrongCount: Int,
        mode: String,
        additionalData: [String: Any]? = nil
    ) {
        var data: [String: Any] = [
            "type": type,
            "timestamp": Timestamp(date: Date()),
            "sessionID": sessionID,
            "deckSize": deckSize,
            "correctCount": correctCount,
            "wrongCount": wrongCount,
            "mode": mode
        ]

        if let prompt = cardPrompt {
            data["cardPrompt"] = prompt
        }

        if let translation = cardTranslation {
            data["cardTranslation"] = translation
        }

        if let index = currentIndex {
            data["currentIndex"] = index
        }

        if let additional = additionalData {
            data.merge(additional) { (_, new) in new }
        }

        writeLog(data: data)
    }

    private func writeLog(data: [String: Any]) {
        // Write to the "user_actions" collection with auto-generated document ID
        db.collection("user_actions").addDocument(data: data) { error in
            if let error = error {
                #if DEBUG
                print("[FirestoreLogger] Error writing log: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("[FirestoreLogger] Successfully logged: \(data["type"] ?? "unknown")")
                #endif
            }
        }
    }
}
