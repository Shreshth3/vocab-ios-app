//
//  study_vocabApp.swift
//  study-vocab
//
//  Created by Shreshth Srivastava on 4/18/25.
//

import SwiftUI
import FirebaseCore

@main
struct study_vocabApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseApp.configure()
        #if DEBUG
        print("[App] init – starting study-vocab with Firebase")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainView()          // instead of ContentView()
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Flush pending logs when app goes to background or becomes inactive
            if newPhase == .background || newPhase == .inactive {
                Task { @MainActor in
                    FirestoreLogger.shared.flushPendingLogs()
                    #if DEBUG
                    print("[App] Flushing pending logs (scenePhase: \(newPhase))")
                    #endif
                }
            }
        }
    }
}
