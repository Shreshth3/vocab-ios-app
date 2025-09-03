//
//  study_vocabApp.swift
//  study-vocab
//
//  Created by Shreshth Srivastava on 4/18/25.
//

import SwiftUI

@main
struct study_vocabApp: App {
    #if DEBUG
    init() {
        print("[App] init – starting study-vocab")
    }
    #endif
    var body: some Scene {
        WindowGroup {
            MainView()          // instead of ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
