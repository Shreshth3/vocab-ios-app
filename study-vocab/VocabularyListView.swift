//
//  VocabularyListView.swift
//  study-vocab
//
//  Created by Claude Code
//

import SwiftUI

struct VocabularyListView: View {
    let deck: [(prompt: String, translation: String)]

    var body: some View {
        ZStack {
            // Dark background consistent with the rest of the app
            Color(red: 45/255, green: 45/255, blue: 45/255)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header (sticky)
                HStack(spacing: 0) {
                    Text("#")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 35, alignment: .leading)

                    Text("Prompt")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 12)

                    Text("Translation")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(red: 35/255, green: 35/255, blue: 35/255))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top)

                // Word list with lazy loading
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(deck.enumerated()), id: \.offset) { index, card in
                            HStack(spacing: 0) {
                                // Number
                                Text("\(index + 1)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(red: 129/255, green: 215/255, blue: 246/255))
                                    .frame(width: 35, alignment: .leading)

                                // Prompt (Chinese character)
                                Text(card.prompt)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.trailing, 12)

                                // Translation (English)
                                Text(card.translation)
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(red: 55/255, green: 55/255, blue: 55/255))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }

                        // Bottom spacing
                        Spacer(minLength: 20)
                    }
                    .padding(.top)
                    .padding(.bottom)
                }
            }
        }
        .navigationTitle("Vocabulary List (\(deck.count) words)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        VocabularyListView(deck: [
            ("示例", "sample"),
            ("测试", "test"),
            ("学习", "study"),
            ("词汇", "vocabulary"),
            ("应用", "application")
        ])
        .preferredColorScheme(.dark)
    }
}
