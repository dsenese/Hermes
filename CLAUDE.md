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

### Planned Modular Structure
Files will be automatically organized into these groups as development progresses:
- `Hermes/Core/` - DictationEngine, AudioManager, TranscriptionService, WhisperManager
- `Hermes/UI/` - MenuBarView, DictationPopup, SettingsView, OnboardingView  
- `Hermes/Features/` - SmartFormatting, CommandMode, WhisperingMode, CodeDictation
- `Hermes/Team/` - SupabaseManager, AuthManager, TeamDashboard
- `Hermes/Utilities/` - Extensions, Logger, helpers

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

**EARLY DEVELOPMENT**: Project contains only basic Xcode template with:
- Standard SwiftUI app structure with auto-generated Info.plist
- Basic "Hello World" ContentView  
- App sandbox entitlements configured
- Swift Testing framework structure in place
- xcodegen-based project management setup
- Automated file organization scripts
- No dependencies integrated yet
- No core functionality implemented

## Next Steps for Development

1. Integrate WhisperKit and download Whisper models
2. Set up AVFoundation audio capture pipeline
3. Implement basic transcription engine
4. Build menu bar UI with floating dictation popup
5. Add Supabase SDK for team features

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

## General
* Aim to build all functionality using SwiftUI unless there is a feature that is only supported in AppKit.
* Design UI in a way that is idiomatic for the macOS platform and follows Apple Human Interface Guidelines.
* Use SF Symbols for iconography.
* Use the most modern macOS APIs. Since there is no backward compatibility constraint, this app can target the latest macOS version with the newest APIs.
* Use the most modern Swift language features and conventions. Target Swift 6 and use Swift concurrency (async/await, actors) and Swift macros where applicable.
