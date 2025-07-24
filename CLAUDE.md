# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hermes is a macOS dictation app built with SwiftUI, competing with Wispr Flow and WillowVoice. The app prioritizes local AI processing for privacy-focused real-time dictation with <400ms latency. Currently in early development stage (basic Xcode template).

**Key Architecture**: 
- **Frontend**: SwiftUI for macOS (menu bar app with floating dictation popup)
- **Audio Processing**: AVFoundation for 16kHz mono WAV capture with WebRTC VAD
- **AI Models**: WhisperKit with Large-V3-Turbo (Q4 quantized), Distil-Whisper fallback
- **Smart Formatting**: MLX for AI-powered text enhancement
- **Backend**: Supabase for team features, auth, and storage
- **Target**: Apple Silicon optimization, <400MB size, <4% CPU idle

## Development Commands

### Build and Test
```bash
# Build project (standard Xcode)
⌘+B in Xcode

# Install dependencies (when implementing)
brew install whisperkit-cli

# Add Supabase SDK
# Via Swift Package Manager in Xcode: https://github.com/supabase/supabase-swift
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
Files are organized into these implemented groups:
- `Hermes/Core/` - ✅ DictationEngine, AudioManager, TranscriptionService, TextInjector, Constants
- `Hermes/UI/` - ✅ Complete UI system with MenuBarView, MainAppView, DictationPopupView, FloatingDictationMarker, full Onboarding flow, and Components/ library
- `Hermes/Features/` - 📁 Empty (ready for SmartFormatting, CommandMode, etc.)
- `Hermes/Team/` - 📁 Empty (ready for SupabaseManager, AuthManager, TeamDashboard)  
- `Hermes/Utilities/` - ✅ Extensions (Color hex support, notification helpers)

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

## Current Implementation Status

**ADVANCED UI DEVELOPMENT**: Project has evolved significantly beyond basic template:

### Completed Core Architecture
- **DictationEngine**: Advanced async/await engine with performance tracking, real-time transcription handling, and comprehensive error management
- **Menu Bar App**: Complete NSApplicationDelegateAdaptor architecture with multiple window controllers for menu bar, main app, dictation popup, and floating marker
- **State Management**: Reactive updates using @StateObject/@ObservableObject, environment objects, and Combine framework integration

### Implemented UI Components
- **Main Dashboard**: Complete app interface with sidebar navigation, activity timeline, user stats, and upgrade prompts  
- **Menu Bar Interface**: Fully functional with status indicators, quick settings panel, control buttons, and material backgrounds
- **Floating Dictation System**: Advanced floating overlay with hover states, waveform animations, and click-to-dictate functionality
- **Complete Onboarding Flow**: 4-step professional onboarding with OAuth authentication, permissions, setup, and interactive demos

### Custom Component Library
- **ButtonStyles.swift**: Primary/secondary buttons, OAuth buttons following official design guidelines (Google, Microsoft, Apple, SSO), 3D keyboard keys
- **HermesTextField.swift**: Custom input fields with hover/focus states, integrated with design system  
- **HermesDropdown.swift**: Professional dropdown component for forms
- **OnboardingCoordinator**: State management for multi-step onboarding flow with sub-steps

### UI Implementation Highlights  
- Professional OAuth integration with proper brand guidelines
- Real-time transcription display with audio visualization
- Privacy mode selection and welcome surveys
- Responsive animations with consistent timing
- Accessibility focus management and VoiceOver considerations

### Interfaces Ready for Integration
- **TranscriptionService**: Interface ready for WhisperKit integration
- **AudioManager**: Audio capture infrastructure in place
- **TextInjector**: System text injection capabilities
- **Team Features**: Folder structure ready for Supabase integration

## Next Steps for Development

1. Integrate WhisperKit with TranscriptionService interface
2. Implement actual audio processing in AudioManager  
3. Connect DictationEngine to real transcription models
4. Add Supabase SDK for team features and authentication
5. Implement MLX smart formatting in Features/ folder
6. Add comprehensive unit and integration tests

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

## Architecture Patterns and Development Guidelines

### App Architecture
- **Menu Bar App Pattern**: Uses NSApplicationDelegateAdaptor with AppDelegate for multiple window controllers
- **SwiftUI + AppKit Integration**: NSHostingView for SwiftUI content in NSWindow/NSPanel structures
- **Floating Window System**: Custom NSFloatingPanel for always-on-top dictation interfaces
- **Modern Swift Concurrency**: Async/await throughout DictationEngine and audio processing
- **Reactive State Management**: @StateObject/@ObservableObject with Combine framework integration

### UI Component Patterns
- **Design System Consistency**: All components use HermesConstants.primaryAccentColor (#CCFF00 Neon Robin)
- **Modular Component Library**: Custom ButtonStyles, HermesTextField, HermesDropdown with convenience extensions
- **OAuth Integration**: Follow official design guidelines for Google, Microsoft, Apple, SSO buttons
- **Animation Standards**: Consistent timing with .easeInOut(duration: 0.1-0.3) patterns
- **Accessibility First**: Proper focus management, VoiceOver support, WCAG 2.1 compliance

### Development Standards
- **SwiftUI Primary**: Use SwiftUI unless AppKit-specific features required (floating windows, global hotkeys)
- **macOS Native**: Follow Apple Human Interface Guidelines, use SF Symbols, target latest macOS APIs
- **Swift 6 Ready**: Use modern Swift language features, async/await, actors, and Swift macros where applicable
- **Component Reusability**: Create extensions like .primaryButtonStyle(), .gmailButtonStyle() for consistent usage
