import SwiftUI
import UniformTypeIdentifiers   // Needed for .fileImporter

struct MainView: View {
    @State private var showingImporter = false
    @State private var folderURL: URL? = nil
    @State private var fileURLs: [URL] = []
    @State private var selectedFileURLs: Set<URL> = []
    @State private var folderAccessGranted = false
    @State private var attemptedDefaultImport = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigateToMerged = false
    @State private var mergedDeck: [(prompt: String, translation: String)]? = nil

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
                            ContentView(deck: deck)
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
                                    NavigationLink {
                                        if let deck = parseVocabularyFile(at: url) {
                                            ContentView(deck: deck)
                                        } else {
                                            Text("Failed to load file")
                                        }
                                    } label: {
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

                    // Bottom actions: choose folder and start studying
                    HStack(spacing: 12) {
                        Button("Choose Folder") {
                            showingImporter = true
                        }
                        .buttonStyle(PressableAccentButtonStyle())

                        Button("Start Studying") {
                            startMergedStudy()
                        }
                        .buttonStyle(PressableAccentButtonStyle(backgroundColor: .blue))
                        .disabled(selectedFileURLs.isEmpty)
                        .opacity(selectedFileURLs.isEmpty ? 0.6 : 1)
                    }
                    .padding(.bottom)
                }
                .padding(.top)
            }
            // MARK: – Folder picker (iCloud / Files)
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.folder],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        // Stop access to previously chosen folder, if any
                        if folderAccessGranted, let previous = folderURL {
                            previous.stopAccessingSecurityScopedResource()
                            folderAccessGranted = false
                        }

                        folderURL = url
                        folderAccessGranted = url.startAccessingSecurityScopedResource()

                        loadFiles(from: url)
                    }
                case .failure(let error):
                    print("Folder import failed:", error.localizedDescription)
                }
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
        } else {
            selectedFileURLs.insert(url)
        }
    }

    private func startMergedStudy() {
        // Ensure deterministic order by using current file list order
        let chosen = fileURLs.filter { selectedFileURLs.contains($0) }
        var combined: [(prompt: String, translation: String)] = []
        for url in chosen {
            if let deck = parseVocabularyFile(at: url) {
                combined.append(contentsOf: deck)
            }
        }
        guard !combined.isEmpty else { return }
        mergedDeck = combined
        navigateToMerged = true
    }
}

// MARK: – Preview
#Preview {
    MainView()
        .preferredColorScheme(.dark)
}
