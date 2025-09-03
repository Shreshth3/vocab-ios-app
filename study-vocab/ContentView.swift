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

    init(deck: [(prompt: String, translation: String)]) {
        self.originalDeck = deck
        _deck = State(initialValue: deck.shuffled())
    }

    @State private var showTranslation = false
    @State private var deck: [(prompt: String, translation: String)]
    @State private var currentIndex = 0
    @State private var correctCards: [(prompt: String, translation: String)] = []
    @State private var wrongCards: [(prompt: String, translation: String)] = []

    private var currentCard: (prompt: String, translation: String) {
        deck[currentIndex]
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
                        deck = originalDeck.shuffled()
                        currentIndex = 0
                        correctCards = []
                        wrongCards = []
                        showTranslation = false
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
                                wrongCards.append(currentCard)
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
                                correctCards.append(currentCard)
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
                                deck = wrongCards.shuffled()
                                correctCards = []
                                wrongCards = []
                                currentIndex = 0
                                showTranslation = false
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
                        deck = wrongCards.shuffled()
                        correctCards = []
                        wrongCards = []
                        currentIndex = 0
                        showTranslation = false
                    }
                    .buttonStyle(PressableAccentButtonStyle())
                    .padding(.horizontal, 8)
                    .disabled(wrongCards.isEmpty)
                    .opacity(wrongCards.isEmpty ? 0.5 : 1)
                }
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
