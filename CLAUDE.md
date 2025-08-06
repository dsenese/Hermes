# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hermes is a macOS dictation app built with SwiftUI, competing with Wispr Flow and WillowVoice. The app prioritizes local AI processing for privacy-focused real-time dictation with <400ms latency.

**Current Status**: Advanced UI implementation with comprehensive onboarding flow, menu bar architecture, and core engine foundation. Global hotkey system implemented with hold-to-dictate functionality.

**Key Architecture**: 
- **Frontend**: SwiftUI menu bar app with multi-window management (main app, menu bar dropdown, floating marker)
- **Audio Processing**: AVFoundation for 16kHz mono WAV capture, energy-based VAD
- **AI Models**: WhisperKit service layer ready (Large-V3-Turbo + Distil-Large-V3 fallback)
- **Text Injection**: macOS Accessibility API with keyboard simulation fallback
- **Hotkey System**: GlobalShortcutManager with Input Monitoring + Accessibility permissions
- **State Management**: Combine + SwiftUI reactive architecture with async/await
- **Target**: Apple Silicon optimization, <400MB size, <4% CPU idle, <400ms latency

## Development Commands

### Build and Test
```bash
# Build project in Xcode (Cmd+B) or command line
xcodebuild -project Hermes.xcodeproj -scheme Hermes -configuration Debug build

# Check for build errors quickly
xcodebuild -project Hermes.xcodeproj -scheme Hermes build 2>&1 | grep -E "error:|warning:|Build succeeded|Build failed"

# Run tests (Swift Testing framework)
xcodebuild test -project Hermes.xcodeproj -scheme Hermes

# Run specific test
# Note: Uses @Test annotations, not XCTest
xcodebuild test -project Hermes.xcodeproj -scheme Hermes -only-testing:HermesTests
```

### Project Management with xcodegen
```bash
# Update Xcode project after adding new files
./scripts/update-project.sh

# Update project and open in Xcode
./scripts/update-project.sh --open

# Manual xcodegen run
xcodegen
```

**Critical**: This project uses `xcodegen` for automatic file management. The `project.yml` file defines the project structure, and new Swift files are automatically detected and added to the appropriate groups. Always run `./scripts/update-project.sh` after creating new files.

## Core Architecture Implementation

### Permission System Architecture
```
Permission Management Stack
├── AccessibilityManager (TCC API access for text injection)
├── InputMonitoringManager (Global key event monitoring)
└── GlobalShortcutManager (Coordinates both for hotkey functionality)
```

**Important**: Global hotkeys require BOTH Accessibility AND Input Monitoring permissions:
- **Accessibility**: Required for text injection via AXUIElement APIs
- **Input Monitoring**: Required to receive global keyDown/keyUp events

### Menu Bar App Architecture Pattern
```
HermesApp (@main entry point)
├── AppDelegate (NSApplicationDelegateAdaptor)
│   ├── MenuBarWindowController → MenuBarView (status item dropdown)
│   ├── MainAppWindowController → MainAppView (dashboard)
│   └── FloatingDictationController → FloatingDictationMarker
└── UserSettings (global settings management)
```

### Core Engine Coordination
```
DictationEngine (Main Coordinator - @ObservableObject)
├── AudioManager (AVFoundation capture, VAD)
├── TranscriptionService (WhisperKit integration layer)
└── TextInjector (Accessibility API + keyboard fallback)

GlobalShortcutManager (Hotkey handling)
├── Hold-to-dictate pattern implementation
├── Context detection (global vs local)
└── Permission coordination
```

**State Flow**: 
1. Hotkey press → GlobalShortcutManager → DictationEngine.startDictation()
2. Audio capture → VAD → Accumulation → Transcription on release
3. Text injection → Active app cursor position

### Dictation Context System
```swift
enum DictationContext {
    case global    // Inject text into active app
    case local     // Handle within Hermes (e.g., Notes view)
}
```

## Key Implementation Details

### Global Hotkey System
- **Hold-to-dictate**: Press and hold to record, release to transcribe and inject
- **Configurable**: Users set hotkey during onboarding (default: fn key)
- **Universal**: Works in all macOS applications when permissions granted
- **Context-aware**: Always uses global context for hotkey-initiated dictation

### Permission Handling
```swift
// AccessibilityManager
- Uses AXIsProcessTrusted() API with functional testing fallback
- DEVELOPMENT_BYPASS_API_CHECK flag for unreliable API during development
- Polls every 10 seconds to detect permission changes

// InputMonitoringManager  
- Tests NSEvent.addGlobalMonitorForEvents capability
- Opens System Preferences to Input Monitoring section if needed
- Required for receiving keyDown/keyUp events globally
```

### Text Injection Strategy
1. **Primary**: Accessibility API (AXUIElement) for direct text insertion
2. **Fallback**: Keyboard simulation using CGEvent when API fails
3. **Smart replacement**: Tracks last injected text for updates during continuous dictation

## Current Implementation Status

**✅ Fully Implemented:**
- Complete menu bar app structure with window management
- Comprehensive 4-step onboarding flow with hotkey configuration
- Global hotkey system with hold-to-dictate functionality
- Audio capture pipeline (16kHz mono, energy-based VAD)
- Text injection system (Accessibility API + keyboard simulation)
- Permission management (Accessibility + Input Monitoring)
- Custom UI component library with design system consistency

**⚠️ Service Layers Ready for Integration:**
- WhisperKit service structure (using placeholder transcription)
- Team features folder structure (ready for Supabase)

**❌ Major Features Pending:**
- WhisperKit model downloading and initialization
- Smart text formatting with MLX
- In-app purchases and subscription management
- Performance optimization to meet <400ms latency target

## Development Guidelines

### SwiftUI + Modern Swift Architecture
- **Primary Framework**: SwiftUI for all UI unless AppKit required (floating windows, global hotkeys)
- **Concurrency**: Async/await throughout, actor isolation for audio processing
- **State Management**: Combine publishers + @StateObject/@ObservableObject reactive patterns
- **App Lifecycle**: `.regular` activation policy (with dock icon for main app access)

### Component Design System
- **Color Consistency**: `HermesConstants.primaryAccentColor` (#CCFF00 Neon Robin) for all accents
- **Button Extensions**: `.primaryButtonStyle()`, `.secondaryButtonStyle()`, service-specific styles
- **Animation Standards**: `.easeInOut(duration: 0.1-0.3)` for consistent timing
- **Dark/Light Mode**: Full theme support with design system colors

### Performance and Privacy Requirements
- **Latency Target**: <400ms end-to-end transcription
- **Local Processing**: All AI on-device, no cloud audio transmission
- **Resource Limits**: <400MB app size, <4% CPU idle, <4s launch time
- **Accessibility**: WCAG 2.1 compliance, VoiceOver support throughout

## Testing and Debugging

### Common Issues and Solutions

**Hotkey not working:**
1. Check Input Monitoring permission in System Preferences → Security & Privacy → Privacy → Input Monitoring
2. Verify Accessibility permission is also granted
3. Look for keyDown/keyUp events in logs (not just modifier events)

**Text not injecting:**
1. Verify context is `.global` for external apps
2. Check Accessibility permission status
3. Look for injection logs and fallback to keyboard simulation

**Permission false negatives:**
- AccessibilityManager has `DEVELOPMENT_BYPASS_API_CHECK = true` for development
- Some apps (Pages, Xcode) may show functional test failures - this is normal

### Logging Controls
- Reduce spam: Permission managers poll less frequently
- GlobalShortcutManager only logs 10% of modifier events
- Look for emoji prefixes: 🔍 (debug), ✅ (success), ❌ (error), 🚀 (start), ⏹️ (stop)

## Repository Information

- **Version Control**: GitHub repository (https://github.com/dsenese/Hermes.git)
- **Development Timeline**: 5-month cycle (started July 23, 2025)
- **Deployment**: App Store via TestFlight for beta testing

## Next Priority Development Tasks

1. **WhisperKit Integration**: Complete `TranscriptionService.swift` with actual model loading
   - Initialize Large-V3-Turbo and Distil-Large-V3 models
   - Replace placeholder transcription in `transcribe()` method
   - Implement model downloading with progress tracking

2. **Performance Optimization**: Meet <400ms latency target
   - Optimize audio chunking strategy
   - Implement more sophisticated VAD (WebRTC integration)
   - Add model quantization and acceleration

3. **Settings UI**: Add keyboard shortcut configuration in MainAppView
   - HotkeyRecorder component integration
   - Live updating of GlobalShortcutManager
   - Persist to UserSettings

4. **Team Features Backend**: Supabase integration for collaboration
   - Authentication flow implementation
   - Shared dictionary and settings sync
   - Team dashboard and admin features

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.