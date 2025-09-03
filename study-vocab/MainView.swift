import SwiftUI
import UniformTypeIdentifiers   // Needed for .fileImporter

struct MainView: View {
    @State private var showingImporter = false
    @State private var folderURL: URL? = nil
    @State private var fileURLs: [URL] = []
    @State private var folderAccessGranted = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background consistent with the rest of the app
                Color(red: 45/255, green: 45/255, blue: 45/255)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // MARK: – Initial state — no folder chosen
                    if folderURL == nil {
                        Button("Import Folder") {
                            showingImporter = true
                        }
                        .buttonStyle(PressableAccentButtonStyle())   // Style defined in ContentView.swift
                        
                    // MARK: – Folder chosen — list files
                    } else {
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
                                        Text(url.lastPathComponent)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(PressableAccentButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)
                        }
                        
                        Button("Choose Another Folder") {
                            showingImporter = true
                        }
                        .buttonStyle(PressableAccentButtonStyle())
                        .padding(.bottom)
                    }
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
        }
    }

    // Parse a vocabulary TSV file into flashcard tuples
    private func parseVocabularyFile(at fileURL: URL) -> [(prompt: String, translation: String)]? {
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
}

// MARK: – Preview
#Preview {
    MainView()
        .preferredColorScheme(.dark)
}