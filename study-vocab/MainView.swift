import SwiftUI
import FirebaseFirestore

struct MainView: View {
    @State private var folderURL: URL? = nil
    @State private var fileURLs: [URL] = []
    @State private var selectedFileURLs: Set<URL> = []
    @State private var attemptedDefaultImport = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigateToMerged = false
    @State private var mergedDeck: [(prompt: String, translation: String)]? = nil
    @State private var currentMode: String = "study"
    @State private var isLoadingReviewData = false
    @State private var wordProbabilities: [String: Double]? = nil
    @State private var navigateToList = false
    @State private var listDeck: [(prompt: String, translation: String)]? = nil

    // MARK: – Default folder
    // Prefer a bundled folder reference named "vocab-lists" (wired in the Xcode project)
    // which points to ../../quizlet-automations/vocab-ui/vocab-lists relative to project root.
    // Fallback to absolute path if the bundle reference is unavailable on this machine.
    private let bundledDefaultFolderName = "vocab-lists"
    private let fallbackDefaultFolderAbsolutePath = "/Users/shreshth/git-repos/quizlet-automations/vocab-ui/vocab-lists"

    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background consistent with the rest of the app
                Color(red: 45/255, green: 45/255, blue: 45/255)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Hidden navigation for merged study session
                    NavigationLink(isActive: $navigateToMerged) {
                        if let deck = mergedDeck {
                            ContentView(deck: deck, mode: currentMode, wordProbabilities: wordProbabilities)
                        } else {
                            Text("")
                        }
                    } label: { EmptyView() }
                    .hidden()

                    // Hidden navigation for vocabulary list view
                    NavigationLink(isActive: $navigateToList) {
                        if let deck = listDeck {
                            VocabularyListView(deck: deck)
                        } else {
                            Text("")
                        }
                    } label: { EmptyView() }
                    .hidden()

                    // MARK: – File list (when a folder is selected or default loaded)
                    if folderURL != nil {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(fileURLs, id: \.self) { url in
                                    NavigationLink(value: url) {
                                        HStack(spacing: 12) {
                                            Button(action: {
                                                toggleSelection(for: url)
                                            }) {
                                                Image(systemName: selectedFileURLs.contains(url) ? "checkmark.square.fill" : "square")
                                                    .foregroundColor(.blue)
                                            }
                                            .buttonStyle(.plain)

                                            Text(url.lastPathComponent)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    .buttonStyle(PressableAccentButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)
                        }
                    } else {
                        // Placeholder when no folder is available yet
                        Text("No folder selected")
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top)
                    }

                    // View List button (aligned to the right)
                    HStack {
                        Spacer()
                        Button("View List") {
                            viewList()
                        }
                        .buttonStyle(PressableAccentButtonStyle())
                        .disabled(selectedFileURLs.isEmpty)
                        .opacity(selectedFileURLs.isEmpty ? 0.6 : 1)
                    }
                    .padding(.horizontal)

                    // Bottom actions: review and start studying
                    HStack(spacing: 12) {
                        Spacer()

                        Button("Review") {
                            #if DEBUG
                            print("\n[MainView] Review button pressed!")
                            print("[MainView] selectedFileURLs.count = \(selectedFileURLs.count)")
                            for url in selectedFileURLs {
                                print("[MainView]   - \(url.lastPathComponent)")
                            }
                            #endif
                            Task {
                                await startMergedStudy(mode: "review")
                            }
                        }
                        .buttonStyle(PressableAccentButtonStyle())
                        .disabled(selectedFileURLs.isEmpty || isLoadingReviewData)
                        .opacity(selectedFileURLs.isEmpty || isLoadingReviewData ? 0.6 : 1)

                        Button("Start Studying") {
                            #if DEBUG
                            print("\n[MainView] Start Studying button pressed!")
                            print("[MainView] selectedFileURLs.count = \(selectedFileURLs.count)")
                            for url in selectedFileURLs {
                                print("[MainView]   - \(url.lastPathComponent)")
                            }
                            #endif
                            Task {
                                await startMergedStudy(mode: "study")
                            }
                        }
                        .buttonStyle(PressableAccentButtonStyle(backgroundColor: .blue))
                        .disabled(selectedFileURLs.isEmpty || isLoadingReviewData)
                        .opacity(selectedFileURLs.isEmpty || isLoadingReviewData ? 0.6 : 1)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.top)

                // Loading indicator overlay
                if isLoadingReviewData {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text("Fetching review data...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(32)
                        .background(Color(red: 45/255, green: 45/255, blue: 45/255))
                        .cornerRadius(16)
                    }
                }
            }
        }
        .navigationDestination(for: URL.self) { url in
            if let deck = parseVocabularyFile(at: url) {
                ContentView(deck: deck)
            } else {
                Text("Failed to load file")
            }
        }
        .onAppear {
            // Attempt default import once on first appear
            if !attemptedDefaultImport {
                attemptedDefaultImport = true
                if let bundleURL = Bundle.main.url(forResource: bundledDefaultFolderName, withExtension: nil) {
                    self.folderURL = bundleURL
                    loadFiles(from: bundleURL)
                    #if DEBUG
                    print("[MainView] Loaded bundled default folder:", bundleURL.path)
                    #endif
                } else {
                    let defaultURL = URL(fileURLWithPath: fallbackDefaultFolderAbsolutePath, isDirectory: true)
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: defaultURL.path, isDirectory: &isDir), isDir.boolValue {
                        self.folderURL = defaultURL
                        loadFiles(from: defaultURL)
                        #if DEBUG
                        print("[MainView] Loaded fallback default folder:", defaultURL.path)
                        #endif
                    } else {
                        #if DEBUG
                        print("[MainView] Default folder missing or not a directory:", defaultURL.path)
                        #endif
                    }
                }
            }
            #if DEBUG
            print("[MainView] onAppear – ready")
            #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            #if DEBUG
            print("[MainView] scenePhase ->", String(describing: newPhase))
            #endif
        }
    }
    
    // MARK: – Helpers
    private func loadFiles(from folderURL: URL) {
        var collected: [URL] = []
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            
            collected = contents.filter { url in
                // Keep only regular files (exclude subfolders)
                (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            }
            // Sort by start number parsed from filename: "subtlex-<start>-<end>.txt"
            collected = collected.sorted { lhs, rhs in
                let l = startNumber(from: lhs)
                let r = startNumber(from: rhs)
                if l != r { return l < r }
                // Tie-breaker for unexpected duplicates
                return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
            }
            
        } catch {
            print("Failed to list folder contents:", error.localizedDescription)
        }

        // Always update state on the main thread
        DispatchQueue.main.async {
            self.fileURLs = collected
            // Clear selections that are no longer present
            self.selectedFileURLs = self.selectedFileURLs.intersection(Set(collected))
            #if DEBUG
            print("[MainView] Loaded files:", collected.map { $0.lastPathComponent })
            #endif
        }
    }

    // Extract the numeric start value from filenames like: "subtlex-<start>-<end>.txt"
    private func startNumber(from url: URL) -> Int {
        let name = url.deletingPathExtension().lastPathComponent
        // Expected: ["subtlex", "<start>", "<end>"]
        let parts = name.split(separator: "-")
        if parts.count >= 3, parts[0].lowercased() == "subtlex", let start = Int(parts[1]) {
            return start
        }
        return Int.max // Push unexpected filenames to the end
    }

    // Parse a vocabulary TSV file into flashcard tuples
    private func parseVocabularyFile(at fileURL: URL) -> [(prompt: String, translation: String)]? {
        #if DEBUG
        print("[Parser] Reading:", fileURL.path)
        #endif
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let cards: [(prompt: String, translation: String)] = content.split(separator: "\n").map { line in
            let parts = line.components(separatedBy: "\t")
            let prompt = String(parts[0])
            let translation = parts.count > 1 ? parts[1] : ""
            return (prompt: prompt, translation: translation)
        }

        return cards
    }

    private func toggleSelection(for url: URL) {
        if selectedFileURLs.contains(url) {
            selectedFileURLs.remove(url)
            #if DEBUG
            print("[MainView] Deselected: \(url.lastPathComponent) | Total selected: \(selectedFileURLs.count)")
            #endif
        } else {
            selectedFileURLs.insert(url)
            #if DEBUG
            print("[MainView] Selected: \(url.lastPathComponent) | Total selected: \(selectedFileURLs.count)")
            #endif
        }
    }

    private func startMergedStudy(mode: String = "study") async {
        // Set loading state
        isLoadingReviewData = true
        defer { isLoadingReviewData = false }

        // Ensure deterministic order by using current file list order
        let chosen = fileURLs.filter { selectedFileURLs.contains($0) }

        #if DEBUG
        print("\n" + String(repeating: "=", count: 80))
        print("[MainView] startMergedStudy called with mode: \(mode)")
        print("[MainView] Total files available: \(fileURLs.count)")
        print("[MainView] Files selected: \(selectedFileURLs.count)")
        print("[MainView] Selected file names:")
        for url in selectedFileURLs {
            print("  - \(url.lastPathComponent)")
        }
        print("[MainView] Chosen files (after filter): \(chosen.count)")
        for url in chosen {
            print("  - \(url.lastPathComponent)")
        }
        print(String(repeating: "=", count: 80) + "\n")
        #endif

        var combined: [(prompt: String, translation: String)] = []
        for url in chosen {
            if let deck = parseVocabularyFile(at: url) {
                combined.append(contentsOf: deck)
            }
        }
        guard !combined.isEmpty else { return }

        // If mode is "review", fetch historical review data from Firebase
        if mode == "review" {
            let prompts = combined.map { $0.prompt }

            #if DEBUG
            print("[MainView] Fetching review records for \(prompts.count) prompts...")
            print("[MainView] First 10 prompts: \(prompts.prefix(10))")
            print("[MainView] Searching for mode='review' AND cardPrompt in deck")
            #endif

            let reviewRecords = await FirestoreLogger.shared.fetchReviewRecords(for: prompts)

            #if DEBUG
            print(String(repeating: "=", count: 80))
            print("[MainView] Fetched \(reviewRecords.count) review records")
            print(String(repeating: "=", count: 80))

            // Print each record with formatted output
            for (index, record) in reviewRecords.enumerated() {
                print("\nRecord #\(index + 1):")
                print("  Document ID: \(record["documentID"] ?? "N/A")")
                print("  Type: \(record["type"] ?? "N/A")")
                print("  Card Prompt: \(record["cardPrompt"] ?? "N/A")")
                print("  Card Translation: \(record["cardTranslation"] ?? "N/A")")
                print("  Mode: \(record["mode"] ?? "N/A")")

                if let timestamp = record["timestamp"] as? Timestamp {
                    print("  Timestamp: \(timestamp.dateValue())")
                }

                if let sessionID = record["sessionID"] {
                    print("  Session ID: \(sessionID)")
                }

                if let correctCount = record["correctCount"] {
                    print("  Correct Count: \(correctCount)")
                }

                if let wrongCount = record["wrongCount"] {
                    print("  Wrong Count: \(wrongCount)")
                }

                print(String(repeating: "-", count: 80))
            }

            print("\n" + String(repeating: "=", count: 80))
            print("[MainView] Finished displaying review records")
            print(String(repeating: "=", count: 80) + "\n")
            #endif

            // Compute scores for each word in the deck
            let deckSize = combined.count
            let scoreIncreaseForIncorrect = (1.0 / 120.0) * (Double(deckSize) - 30.0)
            let scoreDecreaseForCorrect = (1.0 / 5.0) * scoreIncreaseForIncorrect

            #if DEBUG
            print("\n" + String(repeating: "=", count: 80))
            print("[MainView] Computing scores for deck")
            print("Deck size: \(deckSize)")
            print("Score increase per incorrect: \(scoreIncreaseForIncorrect)")
            print("Score decrease per correct: \(scoreDecreaseForCorrect)")
            print(String(repeating: "=", count: 80))
            #endif

            // Group records by cardPrompt and count correct/wrong actions
            var promptStats: [String: (correctCount: Int, wrongCount: Int)] = [:]

            for record in reviewRecords {
                guard let cardPrompt = record["cardPrompt"] as? String,
                      let type = record["type"] as? String else {
                    continue
                }

                var stats = promptStats[cardPrompt] ?? (correctCount: 0, wrongCount: 0)

                if type == "card_correct" {
                    stats.correctCount += 1
                } else if type == "card_incorrect" {
                    stats.wrongCount += 1
                }

                promptStats[cardPrompt] = stats
            }

            // Compute scores for each word
            var wordScores: [String: Double] = [:]

            for prompt in prompts {
                let stats = promptStats[prompt] ?? (correctCount: 0, wrongCount: 0)
                let wrongCount = stats.wrongCount
                let correctCount = stats.correctCount

                let score: Double
                if wrongCount == 0 {
                    // Never got word wrong
                    score = 1.0
                } else {
                    // Apply scoring formula
                    var computedScore = 1.0 +
                        (Double(wrongCount) * scoreIncreaseForIncorrect) -
                        (Double(correctCount) * scoreDecreaseForCorrect)

                    // Floor at 1.0
                    computedScore = max(1.0, computedScore)
                    score = computedScore
                }

                wordScores[prompt] = score
            }

            // Print summary statistics only (not all words to save space)
            #if DEBUG
            print("\n" + String(repeating: "=", count: 80))
            print("[MainView] Word Score Summary")
            print(String(repeating: "=", count: 80))
            print("Total words: \(wordScores.count)")
            print("Words with score > 1.0: \(wordScores.values.filter { $0 > 1.0 }.count)")
            print("Average score: \(String(format: "%.4f", wordScores.values.reduce(0, +) / Double(wordScores.count)))")
            print(String(repeating: "=", count: 80) + "\n")
            #endif

            // Calculate probability distribution from scores
            let totalScore = wordScores.values.reduce(0, +)
            var probabilities: [String: Double] = [:]

            for (prompt, score) in wordScores {
                probabilities[prompt] = score / totalScore
            }

            wordProbabilities = probabilities

            #if DEBUG
            print("\n" + String(repeating: "=", count: 80))
            print("[MainView] Probability Distribution (top 10 by probability)")
            print(String(repeating: "=", count: 80))

            let sortedProbs = probabilities.sorted { $0.value > $1.value }.prefix(10)
            for (index, (prompt, prob)) in sortedProbs.enumerated() {
                print("\n\(index + 1). Prompt: \(prompt)")
                print("   Probability: \(String(format: "%.4f", prob)) (\(String(format: "%.2f", prob * 100))%)")
                print("   Score: \(String(format: "%.4f", wordScores[prompt] ?? 0))")
            }

            print("\n" + String(repeating: "=", count: 80))
            print("[MainView] Total probability sum: \(String(format: "%.6f", probabilities.values.reduce(0, +)))")
            print(String(repeating: "=", count: 80) + "\n")
            #endif
        } else {
            // Study mode - no probabilities
            wordProbabilities = nil
        }

        mergedDeck = combined
        currentMode = mode
        navigateToMerged = true
    }

    private func viewList() {
        // Ensure deterministic order by using current file list order
        let chosen = fileURLs.filter { selectedFileURLs.contains($0) }

        #if DEBUG
        print("\n[MainView] viewList called")
        print("[MainView] Selected files: \(chosen.count)")
        for url in chosen {
            print("  - \(url.lastPathComponent)")
        }
        #endif

        var combined: [(prompt: String, translation: String)] = []
        for url in chosen {
            if let deck = parseVocabularyFile(at: url) {
                combined.append(contentsOf: deck)
            }
        }

        guard !combined.isEmpty else { return }

        listDeck = combined
        navigateToList = true
    }
}

// MARK: – Preview
#Preview {
    MainView()
        .preferredColorScheme(.dark)
}
