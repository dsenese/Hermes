# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hermes is a macOS dictation app built with SwiftUI, competing with Wispr Flow and WillowVoice. The app prioritizes local AI processing for privacy-focused real-time dictation with <400ms latency.

**Current Status**: Advanced UI implementation with comprehensive onboarding flow, menu bar architecture, and core engine foundation. Ready for WhisperKit integration.

**Key Architecture**: 
- **Frontend**: SwiftUI menu bar app (.accessory) with multi-window management
- **Audio Processing**: AVFoundation for 16kHz mono WAV capture, energy-based VAD
- **AI Models**: WhisperKit service layer ready (Large-V3-Turbo + Distil-Large-V3 fallback)
- **Text Injection**: macOS Accessibility API with keyboard simulation fallback
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

### Testing Framework
- Uses **Swift Testing** (new framework with `@Test` annotations, not XCTest)
- Test files: `HermesTests/HermesTests.swift`, `HermesUITests/`
- Target accuracy: >95% WER (Word Error Rate)

## Project Structure

```
Hermes/
├── Hermes App Specifications (Optimized for Claude Code Parsing).markdown  # Complete project specs
├── Hermes Design System Document.markdown  # UI/UX design system and component specs
├── CLAUDE.md                   # This file - development guidance
├── XCODEGEN_WORKFLOW.md        # xcodegen workflow documentation
├── project.yml                 # xcodegen project configuration
├── scripts/                    # Build and automation scripts
│   ├── update-project.sh       # Update Xcode project from project.yml
│   └── pre-build.sh           # Pre-build automation script
├── Hermes.xcodeproj/           # Generated Xcode project (do not edit manually)
├── Hermes/                     # Main app source
│   ├── HermesApp.swift         # App entry point (basic template)
│   ├── ContentView.swift       # Main UI (currently "Hello World")
│   ├── Core/                   # Core engine files (planned structure)
│   │   └── Constants.swift     # App constants and configuration
│   ├── Hermes.entitlements     # App sandbox permissions
│   └── Assets.xcassets/        # App icons and assets
├── HermesTests/                # Unit tests (Swift Testing framework)
└── HermesUITests/              # UI automation tests
```

### Current Modular Structure
```
Hermes/
├── Core/              # ✅ DictationEngine, AudioManager, TranscriptionService, TextInjector, Constants
├── UI/                # ✅ Complete UI system with menu bar, main app, onboarding flow
│   ├── Components/    # ✅ ButtonStyles, HermesTextField, HermesDropdown
│   └── Onboarding/    # ✅ 4-step flow with sub-navigation
├── Features/          # 📁 Ready for SmartFormatting, CommandMode, etc.
├── Team/              # 📁 Ready for SupabaseManager, AuthManager
└── Utilities/         # ✅ Extensions (Color hex, notifications)
```

## Implementation Roadmap

Refer to the comprehensive specifications document for the 8-step build process:

1. **Project Setup** (1 week) - Dependencies, models, base structure
2. **Core Dictation Engine** (2 weeks) - Audio pipeline, WhisperKit integration
3. **UI and User Flows** (2 weeks) - Menu bar interface, onboarding
4. **Advanced Features** (3 weeks) - Smart formatting, command mode, accessibility
5. **Team Management** (2 weeks) - Supabase integration, admin dashboard
6. **Pricing and Monetization** (1 week) - In-app purchases, $150 lifetime offer
7. **Optimization and Testing** (2 weeks) - Performance tuning, beta prep
8. **Launch Preparation** (1 week) - App Store submission

## Key Dependencies (To Be Integrated)

- **WhisperKit**: Local AI transcription with ANE acceleration
- **AVFoundation**: Audio capture and processing
- **MLX**: Local AI for smart text formatting
- **WebRTC VAD**: Voice activity detection for silence
- **Supabase SDK**: Auth, database, and storage for team features

## Design System

Refer to the **Hermes Design System Document.markdown** for comprehensive UI/UX guidelines:
- **Color Palette**: Neon Robin (#CCFF00) primary accent, minimalist with high contrast
- **Typography**: SF Pro font family with dynamic scaling for accessibility  
- **Components**: Fluid, animated SwiftUI components with theme-aware design
- **Layout**: Icon-based sidebar, white main background, rounded cards inspired by Wispr Flow
- **Principles**: "Speak naturally, design fluidly" - simplicity, accessibility, performance

The design document is structured for direct use in AI prompts when implementing UI components.

## Development Guidelines

### Privacy and Security
- **Local-first processing**: All transcription happens on-device
- **App sandbox enabled**: Limited system access for security
- **Opt-in cloud sync**: Team features require explicit user consent
- **Zero retention**: No audio stored after processing

### Performance Targets
- **Latency**: <400ms end-to-end transcription
- **Resource Usage**: <400MB app size, <4% CPU idle, <4s launch time
- **Accuracy**: >95% transcription accuracy across languages and accents
- **Capacity**: Support ~200,000 characters/month per user

### Accessibility Requirements
- **WCAG 2.1 compliance**: Full accessibility support
- **VoiceOver integration**: Hands-free operation
- **Universal app injection**: Works with any macOS application

## Monetization Model

- **Monthly**: $10/month
- **Annual**: $8/month ($96/year)
- **Launch Offer**: Limited $150 lifetime access
- **Free Trial**: 14-day trial period

## Core Architecture Implementation

### Menu Bar App Architecture Pattern
```
HermesApp (@main entry point)
├── AppDelegate (NSApplicationDelegateAdaptor)
│   ├── MenuBarWindowController → MenuBarView (status item dropdown)
│   ├── MainAppWindowController → MainAppView (dashboard)
│   ├── DictationPopupWindowController → DictationPopupView
│   └── FloatingDictationController → FloatingDictationMarker
└── OnboardingView (first-run overlay on MainAppView)
```

### Core Engine Coordination
```
DictationEngine (Main Coordinator - @ObservableObject)
├── AudioManager (AVFoundation capture, VAD)
├── TranscriptionService (WhisperKit integration layer)
└── TextInjector (Accessibility API + keyboard fallback)
```

**State Flow**: Audio → VAD → Transcription → Text Injection
- Uses Combine publishers for reactive data flow
- Modern async/await concurrency throughout
- Actor isolation for voice activity detection
- MainActor for UI-related classes

### Key Architectural Decisions

1. **Local-First Privacy**: All transcription on-device, no cloud audio transmission
2. **Multi-Model Strategy**: Large-V3-Turbo (accuracy) + Distil-Large-V3 (performance)
3. **Universal Text Injection**: Accessibility API primary, CGEvent keyboard fallback
4. **Performance Monitoring**: Built-in latency tracking toward <400ms target
5. **XcodeGen Management**: Never edit `.xcodeproj` manually, use `./scripts/update-project.sh`

### Current Implementation Status

**✅ Fully Implemented:**
- Complete menu bar app structure with window management
- Comprehensive 4-step onboarding flow with sub-navigation
- Main dashboard UI with sidebar, trial info, dark/light mode
- Audio capture pipeline (16kHz mono, energy-based VAD)
- Text injection system (Accessibility API + keyboard simulation)
- Custom UI component library with design system consistency
- Performance tracking and error handling infrastructure

**⚠️ Service Layers Ready for Integration:**
- WhisperKit service structure (using placeholder transcription)
- Global hotkey management (framework in place, needs implementation)
- Team features folder structure (ready for Supabase)

**❌ Major Features Pending:**
- WhisperKit model downloading and initialization
- Smart text formatting with MLX
- In-app purchases and subscription management
- Performance optimization to meet <400ms latency target

## Next Priority Development Tasks

1. **WhisperKit Integration**: Complete `TranscriptionService.swift` with actual model loading
   - Initialize Large-V3-Turbo and Distil-Large-V3 models
   - Replace placeholder transcription in `transcribe()` method
   - Implement model downloading with progress tracking

2. **Performance Optimization**: Meet <400ms latency target
   - Optimize audio chunking strategy
   - Implement more sophisticated VAD (WebRTC integration)
   - Add model quantization and acceleration

3. **Global Hotkey Implementation**: Complete hotkey detection
   - Implement system-wide keyboard monitoring
   - Add customizable hotkey combinations
   - Handle hotkey conflicts gracefully

4. **Team Features Backend**: Supabase integration for collaboration
   - Authentication flow implementation
   - Shared dictionary and settings sync
   - Team dashboard and admin features

## Testing Strategy

- **Unit Tests**: Core transcription accuracy and performance
- **Integration Tests**: End-to-end dictation flow
- **UI Tests**: User interface and accessibility compliance
- **Beta Testing**: 50 users via TestFlight before App Store launch

## Repository Information

- **Version Control**: GitHub repository with feature branches (https://github.com/dsenese/Hermes.git)
- **Development Timeline**: 5-month cycle (started July 23, 2025)
- **Deployment**: App Store via TestFlight for beta testing

## xcodegen Workflow Notes

- **Never manually edit** `Hermes.xcodeproj` - it's generated from `project.yml`
- **Always run** `./scripts/update-project.sh` after adding new Swift files
- **Choose "Keep Disk Version"** if Xcode shows file conflict dialogs
- **Close Xcode** before running the update script for best results
- See `XCODEGEN_WORKFLOW.md` for detailed workflow documentation

## Development Standards and Patterns

### SwiftUI + Modern Swift Architecture
- **Primary Framework**: SwiftUI for all UI unless AppKit required (floating windows, global hotkeys)
- **Concurrency**: Async/await throughout, actor isolation for audio processing
- **State Management**: Combine publishers + @StateObject/@ObservableObject reactive patterns
- **App Lifecycle**: `.accessory` activation policy (menu bar only, no dock icon)

### Component Design System
- **Color Consistency**: `HermesConstants.primaryAccentColor` (#CCFF00 Neon Robin) for all accents
- **Button Extensions**: `.primaryButtonStyle()`, `.gmailButtonStyle()`, `.microsoftButtonStyle()` etc.
- **Animation Standards**: `.easeInOut(duration: 0.1-0.3)` for consistent timing
- **Dark/Light Mode**: Use design system colors (`F5F5F7` light, `2C2C2E` dark for sidebar)

### Performance and Privacy Requirements
- **Latency Target**: <400ms end-to-end transcription
- **Local Processing**: All AI on-device, no cloud audio transmission
- **Resource Limits**: <400MB app size, <4% CPU idle, <4s launch time
- **Accessibility**: WCAG 2.1 compliance, VoiceOver support throughout

### File Organization and Naming
- **Automatic Detection**: Swift files auto-included in `project.yml` structure
- **Group Structure**: Core/, UI/, Features/, Team/, Utilities/ logical organization
- **Component Library**: UI/Components/ for reusable elements
- **Extensions**: Utilities/Extensions.swift for framework extensions
