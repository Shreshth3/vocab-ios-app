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
    }
}
