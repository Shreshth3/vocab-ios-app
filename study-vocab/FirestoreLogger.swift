//
//  FirestoreLogger.swift
//  study-vocab
//
//  Append-only logging service for user actions in Cloud Firestore
//

import Foundation
import FirebaseFirestore

/// Singleton service for logging user actions to Cloud Firestore as append-only logs
@MainActor
class FirestoreLogger {
    static let shared = FirestoreLogger()

    private let db = Firestore.firestore()
    private let sessionID: String
    let buffer = LogBuffer.shared

    private init() {
        // Generate a unique session ID when the logger is initialized
        self.sessionID = UUID().uuidString
        #if DEBUG
        print("[FirestoreLogger] Initialized with session ID: \(sessionID)")
        #endif
    }

    /// Log when user marks a card as correct
    func logCardCorrect(prompt: String, translation: String, currentIndex: Int, deckSize: Int, mode: String) {
        logAction(
            type: "card_correct",
            cardPrompt: prompt,
            cardTranslation: translation,
            currentIndex: currentIndex,
            deckSize: deckSize,
            mode: mode
        )
    }

    /// Log when user marks a card as incorrect
    func logCardIncorrect(prompt: String, translation: String, currentIndex: Int, deckSize: Int, mode: String) {
        logAction(
            type: "card_incorrect",
            cardPrompt: prompt,
            cardTranslation: translation,
            currentIndex: currentIndex,
            deckSize: deckSize,
            mode: mode
        )
    }

    /// Log when user undoes their last action
    func logUndo(currentIndex: Int, deckSize: Int, mode: String) {
        logAction(
            type: "undo",
            currentIndex: currentIndex,
            deckSize: deckSize,
            mode: mode
        )
    }

    /// Log when user restarts the deck
    func logRestart(deckSize: Int, mode: String) {
        logAction(
            type: "restart",
            deckSize: deckSize,
            mode: mode
        )
    }

    /// Log when user starts studying mistakes
    func logStudyMistakes(mistakeCount: Int, mode: String) {
        logAction(
            type: "study_mistakes",
            deckSize: mistakeCount,
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
    func logSessionEnd(deckSize: Int, completionRate: Double, mode: String) {
        logAction(
            type: "session_end",
            deckSize: deckSize,
            mode: mode,
            additionalData: ["completionRate": completionRate]
        )
    }

    /// Flush all pending buffered logs to Firestore immediately
    func flushPendingLogs() {
        buffer.flushAll()
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

        // Create a Set for O(1) lookup when filtering
        let promptSet = Set(prompts)

        #if DEBUG
        print("[FirestoreLogger] Fetching all review records from Firestore...")
        print("[FirestoreLogger] Will filter locally for \(prompts.count) prompts")
        print("[FirestoreLogger] First 10 prompts to match: \(Array(prompts.prefix(10)))")
        #endif

        do {
            // Fetch ALL review records in a single query (no batching needed)
            let querySnapshot = try await db.collection("user_actions")
                .whereField("mode", isEqualTo: "review")
                .getDocuments()

            #if DEBUG
            print("[FirestoreLogger] Fetched \(querySnapshot.documents.count) total review records from database")

            // Debug: Show sample records if any exist
            if !querySnapshot.documents.isEmpty {
                print("[FirestoreLogger] Sample records from database:")
                for (index, doc) in querySnapshot.documents.prefix(5).enumerated() {
                    let data = doc.data()
                    print("  Record \(index + 1):")
                    print("    cardPrompt: \(data["cardPrompt"] ?? "nil")")
                    print("    mode: \(data["mode"] ?? "nil")")
                    print("    type: \(data["type"] ?? "nil")")
                }
            } else {
                print("[FirestoreLogger] No review records found in database")
            }
            #endif

            // Filter locally to only records matching our deck
            let filteredResults = querySnapshot.documents.compactMap { document -> [String: Any]? in
                var data = document.data()

                // Check if this record's cardPrompt is in our deck
                guard let cardPrompt = data["cardPrompt"] as? String,
                      promptSet.contains(cardPrompt) else {
                    return nil
                }

                data["documentID"] = document.documentID
                return data
            }

            #if DEBUG
            print("[FirestoreLogger] Filtered to \(filteredResults.count) records matching the selected deck")
            #endif

            return filteredResults
        } catch {
            #if DEBUG
            print("[FirestoreLogger] Error fetching review records: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    // MARK: - Private Helper Methods

    private func logAction(
        type: String,
        cardPrompt: String? = nil,
        cardTranslation: String? = nil,
        currentIndex: Int? = nil,
        deckSize: Int,
        mode: String,
        additionalData: [String: Any]? = nil
    ) {
        var data: [String: Any] = [
            "type": type,
            "timestamp": Timestamp(date: Date()),
            "sessionID": sessionID,
            "deckSize": deckSize,
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
        let logType = data["type"] as? String

        // Buffer card_correct and card_incorrect to allow undo cancellation
        if logType == "card_correct" || logType == "card_incorrect" {
            buffer.push(data: data)
            #if DEBUG
            print("[FirestoreLogger] Buffered log: \(logType ?? "unknown")")
            #endif
        } else {
            // Write immediately for all other log types
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
}
