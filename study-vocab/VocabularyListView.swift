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
        // Ultra-dense two-column word list
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<((deck.count + 1) / 2), id: \.self) { rowIndex in
                    HStack(spacing: 0) {
                        // Left column word pair
                        let leftIndex = rowIndex * 2
                        if leftIndex < deck.count {
                            wordPairView(card: deck[leftIndex], index: leftIndex)
                        }

                        // Right column word pair (if exists)
                        let rightIndex = rowIndex * 2 + 1
                        if rightIndex < deck.count {
                            wordPairView(card: deck[rightIndex], index: rightIndex)
                        } else {
                            // Empty space for odd number of items
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .background(Color(red: 45/255, green: 45/255, blue: 45/255))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func wordPairView(card: (prompt: String, translation: String), index: Int) -> some View {
        HStack(spacing: 6) {
            // Prompt (pinyin only)
            Text(extractPinyin(from: card.prompt))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            // Translation (English)
            Text(card.translation)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            index % 2 == 0
                ? Color(red: 60/255, green: 60/255, blue: 60/255)
                : Color(red: 45/255, green: 45/255, blue: 45/255)
        )
        .frame(maxWidth: .infinity)
    }

    private func extractPinyin(from prompt: String) -> String {
        // Format: "Chinese (pinyin)"
        // Extract text between parentheses
        if let startIndex = prompt.firstIndex(of: "("),
           let endIndex = prompt.firstIndex(of: ")"),
           startIndex < endIndex {
            let pinyin = prompt[prompt.index(after: startIndex)..<endIndex]
            return String(pinyin)
        }
        // Fallback to original if no parentheses found
        return prompt
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
