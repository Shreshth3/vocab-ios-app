//
//  ContentView.swift
//  study-vocab
//
//  Created by Shreshth Srivastava on 4/18/25.
//

import SwiftUI

// Define accent and background colors for pressable buttons
private let PressableAccentColor = Color(red: 129/255, green: 215/255, blue: 246/255)
private let PressableButtonBackground = Color(red: 64/255, green: 64/255, blue: 64/255)

// Custom button style for press feedback
struct PressableAccentButtonStyle: ButtonStyle {
    var backgroundColor = PressableButtonBackground
    var accentColor = PressableAccentColor
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(configuration.isPressed ? backgroundColor.opacity(0.8) : backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(configuration.isPressed ? accentColor : Color.clear, lineWidth: 2)
            )
            .cornerRadius(cornerRadius)
    }
}

struct ContentView: View {
    // Provide the initial deck via the initializer
    private let originalDeck: [(prompt: String, translation: String)]
    private let mode: String
    private let wordProbabilities: [String: Double]?
    private let logger = FirestoreLogger.shared

    // MARK: - Weighted Random Selection
    /// Selects words from the deck based on probability distribution
    /// Uses cumulative distribution and binary search for efficient sampling
    static func selectWordsByProbability(
        deck: [(prompt: String, translation: String)],
        probabilities: [String: Double]
    ) -> [(prompt: String, translation: String)] {
        guard !deck.isEmpty else { return [] }

        // Create array of (word, probability) pairs
        var wordProbs: [(word: (prompt: String, translation: String), prob: Double)] = []
        for word in deck {
            let prob = probabilities[word.prompt] ?? (1.0 / Double(deck.count))
            wordProbs.append((word: word, prob: prob))
        }

        // Build cumulative distribution
        var cumulativeDistribution: [Double] = []
        var cumulative: Double = 0.0

        for item in wordProbs {
            cumulative += item.prob
            cumulativeDistribution.append(cumulative)
        }

        // Sample words with replacement based on probabilities
        var selectedDeck: [(prompt: String, translation: String)] = []

        for _ in 0..<deck.count {
            let randomValue = Double.random(in: 0..<1.0)

            // Binary search in cumulative distribution
            var left = 0
            var right = cumulativeDistribution.count - 1
            var selectedIndex = 0

            while left <= right {
                let mid = (left + right) / 2
                let cumulativeProb = cumulativeDistribution[mid]

                if randomValue < cumulativeProb {
                    selectedIndex = mid
                    right = mid - 1
                } else {
                    left = mid + 1
                }
            }

            selectedDeck.append(wordProbs[selectedIndex].word)
        }

        #if DEBUG
        // Log distribution statistics
        var wordCounts: [String: Int] = [:]
        for word in selectedDeck {
            wordCounts[word.prompt, default: 0] += 1
        }

        print("\n" + String(repeating: "=", count: 80))
        print("[ContentView] Probability-Based Deck Selection")
        print("Total cards: \(selectedDeck.count)")
        print("Unique cards: \(wordCounts.count)")
        print(String(repeating: "=", count: 80))

        let sortedCounts = wordCounts.sorted { $0.value > $1.value }.prefix(10)
        print("\nTop 10 most frequent words in deck:")
        for (index, (prompt, count)) in sortedCounts.enumerated() {
            let prob = probabilities[prompt] ?? 0
            let expectedCount = prob * Double(deck.count)
            print("\(index + 1). \(prompt)")
            print("   Actual: \(count) occurrences (\(String(format: "%.1f", Double(count) / Double(deck.count) * 100))%)")
            print("   Expected: \(String(format: "%.1f", expectedCount)) (\(String(format: "%.1f", prob * 100))%)")
        }
        print(String(repeating: "=", count: 80) + "\n")
        #endif

        return selectedDeck
    }

    init(deck: [(prompt: String, translation: String)], mode: String = "study", wordProbabilities: [String: Double]? = nil) {
        self.originalDeck = deck
        self.mode = mode
        self.wordProbabilities = wordProbabilities

        // Use probability-based selection for review mode, uniform random for study mode
        if let probabilities = wordProbabilities {
            _deck = State(initialValue: Self.selectWordsByProbability(deck: deck, probabilities: probabilities))
        } else {
            _deck = State(initialValue: deck.shuffled())
        }
    }

    @State private var showTranslation = false
    @State private var deck: [(prompt: String, translation: String)]
    @State private var currentIndex = 0
    @State private var correctCards: [(prompt: String, translation: String)] = []
    @State private var wrongCards: [(prompt: String, translation: String)] = []
    @State private var hasLoggedSession = false
    @State private var isReviewingMistakes = false

    private var currentCard: (prompt: String, translation: String) {
        deck[currentIndex]
    }

    private var shouldLog: Bool {
        mode == "review" && !isReviewingMistakes
    }

    var body: some View {
        ZStack {
            Color(red: 45/255, green: 45/255, blue: 45/255)
                .ignoresSafeArea()
            VStack {
                // Counters for incorrect and correct answers
                HStack {
                    Text("Incorrect: \(wrongCards.count)")
                        .foregroundColor(.red)
                        .font(.headline)
                    Spacer()
                    Text("Correct: \(correctCards.count)")
                        .foregroundColor(.green)
                        .font(.headline)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Restart button at top right
                HStack {
                    Spacer()
                    Button {
                        // Log restart action
                        if shouldLog {
                            logger.logRestart(deckSize: originalDeck.count, mode: mode)
                        }

                        deck = originalDeck.shuffled()
                        currentIndex = 0
                        correctCards = []
                        wrongCards = []
                        showTranslation = false
                        isReviewingMistakes = false
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PressableAccentButtonStyle())
                }
                .padding(.horizontal)

                Spacer()

                if currentIndex < deck.count {
                    VStack {
                        Text(currentCard.prompt)
                            .font(.system(size: 48))

                        Text(currentCard.translation)
                            .font(.title)
                            .padding(.top, 8)
                            .opacity(showTranslation ? 1 : 0)
                            .animation(nil, value: showTranslation)

                        Button(action: { showTranslation.toggle() }) {
                            Text("Toggle Translation")
                        }
                        .buttonStyle(PressableAccentButtonStyle())
                        .padding(.top, 8)

                        HStack(spacing: 50) {
                            Button(action: {
                                let card = currentCard
                                wrongCards.append(card)

                                // Log the incorrect action
                                if shouldLog {
                                    logger.logCardIncorrect(
                                        prompt: card.prompt,
                                        translation: card.translation,
                                        currentIndex: currentIndex,
                                        deckSize: deck.count,
                                        mode: mode
                                    )
                                }

                                showTranslation = false
                                currentIndex += 1
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                            Button(action: {
                                let card = currentCard
                                correctCards.append(card)

                                // Log the correct action
                                if shouldLog {
                                    logger.logCardCorrect(
                                        prompt: card.prompt,
                                        translation: card.translation,
                                        currentIndex: currentIndex,
                                        deckSize: deck.count,
                                        mode: mode
                                    )
                                }

                                showTranslation = false
                                currentIndex += 1
                            }) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.green)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.top, 20)
                    }
                } else {
                    VStack(spacing: 20) {
                        Text("You've completed the deck!")
                            .font(.title)
                        if wrongCards.isEmpty {
                            Text("All words correct! 🎉")
                        } else {
                            Button("Mistakes") {
                                let mistakeCount = wrongCards.count

                                // Log study mistakes action
                                if shouldLog {
                                    logger.logStudyMistakes(mistakeCount: mistakeCount, mode: mode)
                                }

                                deck = wrongCards.shuffled()
                                correctCards = []
                                wrongCards = []
                                currentIndex = 0
                                showTranslation = false
                                isReviewingMistakes = true
                            }
                            .buttonStyle(PressableAccentButtonStyle())
                        }
                    }
                }

                // Bottom controls for Undo and Restart
                Spacer()
                HStack(spacing: 12) {
                    Spacer().frame(maxWidth: 40)
                    Button {
                        if currentIndex > 0 {
                            currentIndex -= 1
                            let card = deck[currentIndex]
                            if let idx = correctCards.lastIndex(where: { $0.prompt == card.prompt && $0.translation == card.translation }) {
                                correctCards.remove(at: idx)
                            } else if let idx = wrongCards.lastIndex(where: { $0.prompt == card.prompt && $0.translation == card.translation }) {
                                wrongCards.remove(at: idx)
                            }

                            // Try to cancel buffered log entry first
                            Task { @MainActor in
                                let wasCanceled = logger.buffer.pop()

                                // If buffer was empty (entry already flushed), log undo as fallback
                                if !wasCanceled && shouldLog {
                                    logger.logUndo(
                                        currentIndex: currentIndex,
                                        deckSize: deck.count,
                                        mode: mode
                                    )
                                }
                            }

                            showTranslation = false
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PressableAccentButtonStyle())
                    .padding(.trailing, 8)
                    .disabled(currentIndex == 0)
                    .opacity(currentIndex == 0 ? 0.5 : 1)
                    Button("Mistakes") {
                        let mistakeCount = wrongCards.count

                        // Log study mistakes action
                        if shouldLog {
                            logger.logStudyMistakes(mistakeCount: mistakeCount, mode: mode)
                        }

                        deck = wrongCards.shuffled()
                        correctCards = []
                        wrongCards = []
                        currentIndex = 0
                        showTranslation = false
                        isReviewingMistakes = true
                    }
                    .buttonStyle(PressableAccentButtonStyle())
                    .padding(.horizontal, 8)
                    .disabled(wrongCards.isEmpty)
                    .opacity(wrongCards.isEmpty ? 0.5 : 1)
                }
            }
        }
        .onAppear {
            // Log session start only once
            if !hasLoggedSession && shouldLog {
                logger.logSessionStart(deckSize: originalDeck.count, mode: mode)
                hasLoggedSession = true
            }
        }
        .onDisappear {
            // Flush any pending buffered logs when leaving the view
            Task { @MainActor in
                logger.flushPendingLogs()
            }
        }
    }
}

#Preview {
    ContentView(deck: [
        ("示例", "sample"),
        ("测试", "test")
    ])
    .preferredColorScheme(.dark)
}
