# Repository Guidelines

## Project Structure & Module Organization
- `study-vocab/`: SwiftUI app sources (e.g., `MainView.swift`, `ContentView.swift`, `study_vocabApp.swift`) and `Assets.xcassets`.
- `study-vocab.xcodeproj/`: Xcode project; open in Xcode for local dev.
- `study-vocabTests/`: Unit tests (Swift Testing framework).
- `study-vocabUITests/`: UI tests (XCTest).
- `LaunchScreen.storyboard`: Launch screen asset.

## Build, Test, and Development Commands
- Open in Xcode: `xed .` then select the `study-vocab` scheme.
- Build & run (Xcode): Product → Run (select an iOS Simulator, e.g., iPhone 15).
- Unit/UI tests (Xcode): Product → Test.
- CLI build: `xcodebuild -project study-vocab.xcodeproj -scheme study-vocab -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' build`
- CLI tests: `xcodebuild test -project study-vocab.xcodeproj -scheme study-vocab -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'`
  - Replace simulator name/OS as available on your machine.

## Coding Style & Naming Conventions
- Language: Swift (SwiftUI). Prefer Xcode’s default formatter.
- Indentation: 4 spaces; trim trailing whitespace.
- Naming: Types `UpperCamelCase`, properties/functions `lowerCamelCase`, files named after the primary type or view (e.g., `MainView.swift`).
- Imports: Keep minimal and scoped; group system imports together.
- Linting: No linter configured; keep changes small and idiomatic Swift.

## Testing Guidelines
- Frameworks: Unit tests use `Testing`; UI tests use `XCTest`.
- Location: Mirror source files under `study-vocabTests` and `study-vocabUITests`.
- Naming: Suffix test files with `Tests.swift`; name test functions descriptively (e.g., `testParsingTSV()`).
- Focus: Cover file parsing and view logic that can be tested without UI.
- Run: Use Xcode Product → Test or the `xcodebuild test` command above.

## Commit & Pull Request Guidelines
- Commits: Use clear, imperative messages (present tense). Example: `Add TSV parser and wire to MainView`.
- Scope: Keep commits focused; include rationale in body when non-trivial.
- PRs: Provide summary, linked issue (if any), screenshots/screencasts for UI changes, test plan (simulator/device, iOS version), and checklist of impacts (assets, permissions).

## Architecture Notes & Tips
- App: `study_vocabApp` launches `MainView` (folder import, TSV parsing) → `ContentView` (flashcards, dark theme).
- Files access: Uses security-scoped resources; close previous access before switching folders (already handled).
- Assets: Add images/colors to `Assets.xcassets`; keep names stable.
