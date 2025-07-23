# Hermes macOS Dictation App: Full Development Requirements and Step-by-Step Build Process

## 1. Overview
This document provides comprehensive development requirements for Hermes, a macOS dictation app competing with Wispr Flow and WillowVoice. It includes functional and non-functional specs, technical architecture, and a detailed step-by-step build process from start to finish. The app uses local AI for privacy-focused dictation, with optional team features via Supabase for auth, storage, and database. This is optimized for direct pasting into Claude Code (Anthropic's terminal-based AI tool) and Claude Projects. Claude Code will parse this into actionable steps for completion.

**Key Goals**:
- Match or slightly exceed competitors in speed, accuracy, and features.
- Prioritize local processing for privacy.
- Support ~200,000 characters/month per user.
- Build in SwiftUI for macOS, targeting Apple Silicon.

**Assumptions**:
- Development team: Developers familiar with Swift and macOS.
- Tools: Claude Code for code generation, Xcode for builds, GitHub for version control.
- Timeline: 5 months (setup to launch, starting July 23, 2025).
- Pricing: $10/month or $8/month annual ($96/year). Launch offer: Limited one-time $150 lifetime access (use as lever for user acquisition, e.g., seasonal promotions).

**Parsing Instructions for Claude Code**: When pasted, Claude Code should interpret sections as sequential steps. Use prompts like "claude-code create [section description]" to generate code. Break into modular files (e.g., DictationEngine.swift). Add custom instructions in Claude Projects: "Build Hermes in SwiftUI for macOS. Use Supabase for auth, storage, database. Optimize for <400ms latency with WhisperKit. Ensure privacy, accessibility, and Supabase integration for teams."

## 2. Development Requirements
### 2.1 Functional Requirements
- **Real-Time Dictation**: <400ms latency, 100+ languages, hotkey activation, text injection in any app.
- **Smart Formatting**: Auto-format lists, paragraphs, code; AI edits for grammar/tone; personal dictionary.
- **Command Mode**: Voice commands for editing (e.g., delete, format).
- **Whispering Mode**: Handle quiet speech accurately.
- **Code Dictation**: Syntax-aware transcription for programming.
- **Accessibility**: VoiceOver support, hands-free operation.
- **Team Management**: SSO, shared vocab, admin dashboard, billing via Supabase.
- **Integration**: Accessibility API for app injection; Supabase for teams.
- **User Flows**: Onboarding, dictation, settings, team management.
- **Pricing Integration**: $10/month or $8/month annual; $150 lifetime launch offer (limited quantity).

### 2.2 Non-Functional Requirements
- **Performance**: <400ms latency, <400MB size, <4% CPU idle, <4s launch.
- **Security/Privacy**: Local processing; opt-in Supabase sync; SOC 2 compliance.
- **Reliability**: Offline mode; fallbacks for errors.
- **Usability**: WCAG 2.1; intuitive UI with animations.
- **Scalability**: Handle high-volume usage without degradation.
- **Testing**: 95%+ accuracy; unit/integration tests; beta with 50 users.

### 2.3 Technical Requirements
- **Languages/Frameworks**: Swift/SwiftUI.
- **Libraries**: WhisperKit (transcription), AVFoundation (audio), MLX (formatting AI), WebRTC VAD (silence detection), Supabase (auth, storage, database).
- **Models**: Whisper Large-V3-Turbo (Q4 quantized); Distil-Whisper fallback.
- **Dependencies**: Install via Homebrew (e.g., whisperkit-cli); Supabase SDK via SPM.
- **Build Environment**: Xcode 16+, macOS Sonoma+.
- **Version Control**: GitHub with branches for features.
- **Deployment**: App Store submission; TestFlight for beta.

## 3. Step-by-Step Build Process
Claude Code: Parse this section as sequential commands. Execute each step with the provided prompts, generating code and committing to GitHub branches. After each step, test and optimize.

### Step 1: Project Setup (1 Week, Start July 23, 2025)
- Create GitHub repo: "Hermes-App" with .gitignore for Swift.
- Install dependencies: Run in terminal: `brew install whisperkit-cli`, add Supabase SDK via SPM in Xcode.
- Setup base project: Open Xcode, create new SwiftUI app project.
- Claude Code Prompt: "claude-code create 'base SwiftUI macOS project structure with AppDelegate.swift, ContentView.swift, and dependencies for WhisperKit, AVFoundation, MLX, and Supabase.'"
- Add models: Download Large-V3-Turbo and Distil-Whisper from Hugging Face; integrate via WhisperKit.
- Claude Code Prompt: "claude-code integrate 'Whisper models with fallback logic.'"
- Commit: "Initial setup."

### Step 2: Core Dictation Engine (2 Weeks)
- Implement audio pipeline: Capture 16kHz mono WAV with VAD.
- Claude Code Prompt: "claude-code write 'AVFoundation audio capture with WebRTC VAD for silence detection and 5-second streaming chunks to WhisperKit.'"
- Add transcription: Use WhisperKit for real-time processing with ANE acceleration.
- Claude Code Prompt: "claude-code implement 'WhisperKit transcription with Large-V3-Turbo Q4, fallback to Distil-Whisper, targeting <400ms latency.'"
- Test: Run unit tests for accuracy (>95% WER).
- Claude Code Prompt: "claude-code test 'transcription accuracy on sample audio with accents and noise.'"
- Commit: "Core engine complete."

### Step 3: UI and User Flows (2 Weeks)
- Build menu bar icon and popup: SwiftUI views for dictation interface.
- Claude Code Prompt: "claude-code generate 'SwiftUI menu bar icon with dropdown and floating dictation popup showing live transcription.'"
- Implement onboarding and settings: Tabbed panels for customization.
- Claude Code Prompt: "claude-code write 'onboarding flow with hotkey setup and settings panel for language, model, and privacy.'"
- Add animations: Subtle fades for partial/final text.
- Claude Code Prompt: "claude-code add 'animations for gray partial text to black final text in popup.'"
- Test usability: Ensure WCAG compliance.
- Claude Code Prompt: "claude-code check 'WCAG 2.1 accessibility in all views.'"
- Commit: "UI flows ready."

### Step 4: Advanced Features (3 Weeks)
- Smart Formatting: Integrate MLX for auto-edits.
- Claude Code Prompt: "claude-code implement 'MLX AI for formatting lists, paragraphs, code, and grammar fixes based on context.'"
- Command Mode: Parse commands in transcription stream.
- Claude Code Prompt: "claude-code write 'voice command parser for editing like delete and format.'"
- Whispering/Code Modes: Fine-tune models.
- Claude Code Prompt: "claude-code fine-tune 'Whisper for whispering and code syntax modes.'"
- Accessibility: Add VoiceOver.
- Claude Code Prompt: "claude-code add 'hands-free VoiceOver support to all UI elements.'"
- Integration: Text injection.
- Claude Code Prompt: "claude-code implement 'Accessibility API for injecting text into apps like Slack.'"
- Test: End-to-end flows.
- Claude Code Prompt: "claude-code test 'dictation flow from hotkey to injection.'"
- Commit: "Features integrated."

### Step 5: Team Management (2 Weeks)
- Add Supabase: Auth, storage, and database.
- Claude Code Prompt: "claude-code integrate 'Supabase for user auth, SSO/SAML, shared vocab storage, and admin dashboard with database queries.'"
- Build dashboard: UI for seat management/billing.
- Claude Code Prompt: "claude-code write 'SwiftUI admin dashboard for team management and reports using Supabase database.'"
- Privacy Controls: Opt-in sync.
- Claude Code Prompt: "claude-code add 'opt-in encrypted cloud sync with zero retention using Supabase storage.'"
- Test: Multi-user scenarios.
- Claude Code Prompt: "claude-code test 'team flow with invites and shared vocab sync via Supabase.'"
- Commit: "Team features complete."

### Step 6: Pricing and Monetization (1 Week)
- Implement tiers: $10/month, $8/month annual ($96/year).
- Claude Code Prompt: "claude-code implement 'in-app purchase system with App Store Connect for monthly/annual tiers.'"
- Add launch offer: Limited $150 lifetime.
- Claude Code Prompt: "claude-code add 'limited-time $150 lifetime offer with quantity tracking in Supabase database.'"
- Handle trials: 14-day free.
- Claude Code Prompt: "claude-code implement '14-day trial timer with user notifications.'"
- Test: Purchase flows.
- Claude Code Prompt: "claude-code test 'monetization flows including discounts and lifetime offers.'"
- Commit: "Monetization ready."

### Step 7: Optimization and Testing (2 Weeks)
- Performance Tuning: Throttle resources.
- Claude Code Prompt: "claude-code optimize 'for <400MB size, <4% CPU, <4s launch.'"
- Full Testing: Unit/integration, stress (267 min/month).
- Claude Code Prompt: "claude-code generate 'comprehensive tests for latency, accuracy, and offline mode.'"
- Beta Prep: TestFlight setup.
- Claude Code Prompt: "claude-code prepare 'beta distribution script.'"
- Commit: "Optimized and tested."

### Step 8: Launch Preparation (1 Week)
- Privacy Policy: Generate UI.
- Claude Code Prompt: "claude-code write 'privacy settings UI with SOC 2 notes.'"
- App Store Submission: Prepare assets.
- Claude Code Prompt: "claude-code generate 'App Store metadata and screenshots based on specs.'"
- Marketing: Landing page integration.
- Claude Code Prompt: "claude-code add 'in-app links to marketing site for launch offers.'"
- Final Test: End-to-end.
- Claude Code Prompt: "claude-code test 'full app simulation from onboarding to team billing.'"
- Commit: "Ready for launch."

## 4. Post-Build Guidelines
- Monitor: Use Instruments for performance.
- Iterate: Analyze beta feedback with Claude: "claude-code summarize 'feedback logs for fixes.'"
- Deploy: Submit to App Store.

This process ensures a structured build from setup to launch, using Claude Code for efficiency. Paste entire document into Claude Code for parsing into steps.