# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS SwiftUI vocabulary study app that allows users to import TSV files containing word pairs for flashcard-style learning. The app supports folder import, file selection, and flashcard review with progress tracking.

## Development Commands

### Building
```bash
# Build for iOS simulator
xcodebuild -scheme study-vocab -destination "platform=iOS Simulator,name=iPhone 16 Pro"

# Build for device  
xcodebuild -scheme study-vocab -destination "platform=iOS,arch=arm64"
```

### Testing
```bash
# Run unit tests
xcodebuild test -scheme study-vocab -destination "platform=iOS Simulator,name=iPhone 16 Pro"

# Run UI tests
xcodebuild test -scheme study-vocabUITests -destination "platform=iOS Simulator,name=iPhone 16 Pro"
```

### Running
Open `study-vocab.xcodeproj` in Xcode and use Cmd+R to run the app, or use Xcode's built-in simulator controls.

## Architecture

### Core Components

- **study_vocabApp.swift**: Main app entry point, sets up dark theme preference
- **MainView.swift**: Primary view handling folder import and file listing 
- **ContentView.swift**: Flashcard study interface with swipe-to-learn functionality

### Key Features

1. **File Management**: Users can import folders containing TSV vocabulary files through the iOS Files app integration
2. **Security-Scoped Resources**: Proper handling of file access permissions for imported folders
3. **TSV Parsing**: Parses tab-separated vocabulary files with prompt/translation pairs
4. **Flashcard Interface**: Shows prompts, toggleable translations, and right/wrong tracking
5. **Progress Tracking**: Counts correct/incorrect answers and supports mistake review

### UI Components

- **PressableAccentButtonStyle**: Custom button style with press feedback and accent colors
- Dark theme with consistent color scheme: background `Color(red: 45/255, green: 45/255, blue: 45/255)`
- Accent color: `Color(red: 129/255, green: 215/255, blue: 246/255)`

### File Format

The app expects TSV files with tab-separated values:
```
prompt	translation
示例	sample
测试	test
```

## Project Structure

- `study-vocab/`: Main app source code
  - Swift files for UI components and app logic
  - Assets.xcassets for app icons and colors
- `study-vocabTests/`: Unit tests using Swift Testing framework
- `study-vocabUITests/`: UI automation tests
- `LaunchScreen.storyboard`: Launch screen configuration

## Build Configuration

- iOS deployment target: 18.0
- Swift version: 5.0
- Supports both iPhone and iPad (device families 1,2)
- Development team configured for code signing
- Uses automatic code signing