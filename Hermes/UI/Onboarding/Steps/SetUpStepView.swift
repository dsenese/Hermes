//
//  SetUpStepView.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI

/// SET UP step - contains microphone test, keyboard shortcut, and language selection sub-flows
struct SetUpStepView: View {
    @State private var currentSubStep: SetUpSubStep = .microphoneTest
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    var body: some View {
        OnboardingStepContainer(showBackButton: canGoBack) {
            Group {
                switch currentSubStep {
                case .microphoneTest:
                    MicrophoneTestView(onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSubStep = .keyboardShortcut
                        }
                    })
                case .keyboardShortcut:
                    KeyboardShortcutView(onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentSubStep = .languageSelection
                        }
                    })
                case .languageSelection:
                    LanguageSelectionView(onContinue: {
                        coordinator.nextStep()
                    })
                }
            }
        }
        .onAppear {
            // Set up sub-step back navigation handler
            coordinator.subStepBackHandler = handleSubStepBack
        }
        .onDisappear {
            // Clean up handler when leaving this step
            coordinator.subStepBackHandler = nil
        }
    }
    
    private var canGoBack: Bool {
        true // Always show back button since we can always go back to previous main step or sub-step
    }
    
    private func handleSubStepBack() -> Bool {
        switch currentSubStep {
        case .microphoneTest:
            return false // Let main step navigation handle this
        case .keyboardShortcut:
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSubStep = .microphoneTest
            }
            return true
        case .languageSelection:
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSubStep = .keyboardShortcut
            }
            return true
        }
    }
}

enum SetUpSubStep {
    case microphoneTest
    case keyboardShortcut
    case languageSelection
}

// MARK: - Sub-step Views

private struct KeyboardShortcutView: View {
    let onContinue: () -> Void
    @StateObject private var userSettings = UserSettings.shared
    @StateObject private var hotkeyManager = GlobalHotkeyManager.shared
    @State private var showingCustomization = false
    @State private var showingTestDialog = false
    @State private var keyPressed = false
    @State private var keyTestPassed = false
    @State private var currentShortcut = "fn"
    @State private var isListeningForKey = false
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    
    var body: some View {
        VStack(spacing: showingCustomization ? 16 : 32) {
            // Header - hide when customization is showing for maximum space
            if !showingCustomization {
                VStack(spacing: 20) {
                    // Title
                    VStack(spacing: 6) {
                        Text("Press the keyboard")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        Text("shortcut to test it out")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    // Subtitle
                    Text("We recommend Option + Space")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Content area - full space when customization is showing
            if showingCustomization {
                keyCustomizationView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if showingTestDialog {
                keyTestDialog
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Initial prompt with separate key visualization
                VStack(spacing: 32) {
                    HStack(spacing: 4) {
                        Text("Press")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                        
                        // Display keys separately - observe real hotkey presses
                        keyVisualizationRow(isPressed: hotkeyManager.hotkeyPressed)
                            .onChange(of: hotkeyManager.hotkeyPressed) { _, newValue in
                                print("🟢 UI detected hotkeyPressed change: \(newValue)")
                            }
                        
                        Text("to begin")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    
                    // Keyboard visual hint
                    Image(systemName: "keyboard")
                        .font(.system(size: 60))
                        .foregroundColor(Color(NSColor.quaternaryLabelColor))
                }
                .padding(40)
            }
        }
        .onAppear {
            // Set current shortcut from settings
            currentShortcut = userSettings.keyboardShortcuts.globalDictationHotkey.displayString
            
            // Register the hotkey for testing - it will show green when user holds it down
            let hotkeyConfig = userSettings.keyboardShortcuts.globalDictationHotkey
            print("🔧 Registering hotkey for onboarding test: \(hotkeyConfig.displayString)")
            hotkeyManager.registerHotkey(hotkeyConfig, 
                onPressed: {
                    // Hotkey pressed - the UI will update automatically via @Published
                    print("🟢 Hotkey PRESSED during onboarding test!")
                },
                onReleased: {
                    // Hotkey released - the UI will update automatically via @Published
                    print("🟢 Hotkey RELEASED during onboarding test!")
                }
            )
            
            // Show the test dialog after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingTestDialog = true
                }
            }
        }
    }
    
    
    private var keyTestDialog: some View {
        VStack(spacing: 32) {
            Text("Does the button turn green while pressing it?")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Keyboard key visualization with separate keys
            VStack(spacing: 20) {
                // Display keys as separate visual elements - observe real hotkey presses
                keyVisualizationRow(isPressed: hotkeyManager.hotkeyPressed)
                    .onChange(of: hotkeyManager.hotkeyPressed) { _, newValue in
                        print("🟢 Test dialog UI detected hotkeyPressed change: \(newValue)")
                    }
                
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                Button("No, change shortcut") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingTestDialog = false
                        showingCustomization = true
                    }
                }
                .secondaryButtonStyle()
                
                Button("Yes") {
                    keyTestPassed = true
                    // Save the current shortcut to settings and register globally
                    userSettings.saveToLocalStorage()
                    
                    // Register the hotkey globally for immediate use
                    GlobalHotkeyManager.shared.updateHotkey(userSettings.keyboardShortcuts.globalDictationHotkey)
                    
                    onContinue()
                }
                .primaryButtonStyle()
            }
        }
        .padding(32)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        .frame(maxWidth: 480)
    }
    
    private var keyCustomizationView: some View {
        VStack(spacing: 32) {
            Text("Change your keyboard shortcut")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 24) {
                // Preset options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Popular shortcuts")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        shortcutOption("⌥ Space", description: "Option + Space (recommended)")
                        shortcutOption("fn", description: "Function key")
                        shortcutOption("⌘⌘", description: "Double Command")
                        shortcutOption("⌃ Space", description: "Control + Space")
                    }
                }
                
                Divider()
                    .padding(.horizontal, -24)
                
                // Custom option - HotkeyRecorder for advanced users
                VStack(spacing: 16) {
                    Text("Custom shortcut")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    HotkeyRecorder(
                        title: "Record custom shortcut",
                        description: "Press any key combination",
                        hotkey: $userSettings.keyboardShortcuts.globalDictationHotkey
                    )
                    .onChange(of: userSettings.keyboardShortcuts.globalDictationHotkey) { _, newHotkey in
                        currentShortcut = newHotkey.displayString
                        print("🔧 Custom hotkey changed to: \(newHotkey.displayString)")
                        
                        // Register the new hotkey for onboarding test
                        hotkeyManager.registerHotkey(newHotkey, 
                            onPressed: {
                                print("🟢 Custom hotkey PRESSED during onboarding test!")
                            },
                            onReleased: {
                                print("🟢 Custom hotkey RELEASED during onboarding test!")
                            }
                        )
                    }
                }
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingCustomization = false
                        showingTestDialog = true
                    }
                }
                .secondaryButtonStyle()
                
                Button("Save") {
                    userSettings.saveToLocalStorage()
                    
                    // Update the global hotkey registration
                    GlobalHotkeyManager.shared.updateHotkey(userSettings.keyboardShortcuts.globalDictationHotkey)
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingCustomization = false
                        showingTestDialog = true
                    }
                }
                .primaryButtonStyle()
                .disabled(currentShortcut.isEmpty)
            }
        }
        .padding(24)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(maxWidth: 500)
    }
    
    private func shortcutOption(_ shortcut: String, description: String) -> some View {
        Button(action: {
            currentShortcut = shortcut
            isListeningForKey = false
            
            // Update the user settings based on the selected shortcut
            let newHotkey: HotkeyConfiguration
            switch shortcut {
            case "fn":
                newHotkey = HotkeyConfiguration(
                    key: .fn, modifiers: [], description: "Start/Stop Dictation"
                )
            case "⌘⌘":
                newHotkey = HotkeyConfiguration(
                    key: .command, modifiers: [], description: "Start/Stop Dictation"
                )
            case "⌥ Space":
                newHotkey = HotkeyConfiguration(
                    key: .space, modifiers: [.option], description: "Start/Stop Dictation"
                )
            case "⌃ Space":
                newHotkey = HotkeyConfiguration(
                    key: .space, modifiers: [.control], description: "Start/Stop Dictation"
                )
            default:
                return
            }
            
            // Update settings and immediately register the new hotkey globally
            userSettings.keyboardShortcuts.globalDictationHotkey = newHotkey
            userSettings.saveToLocalStorage()
            
            // Register the new hotkey globally and for onboarding test
            print("🔧 Updating hotkey to: \(newHotkey.displayString)")
            hotkeyManager.registerHotkey(newHotkey, 
                onPressed: {
                    print("🟢 New hotkey PRESSED during onboarding test!")
                },
                onReleased: {
                    print("🟢 New hotkey RELEASED during onboarding test!")
                }
            )
            
            // Also update the global system hotkey
            GlobalHotkeyManager.shared.updateHotkey(newHotkey)
        }) {
            HStack {
                // Radio button
                Circle()
                    .fill(currentShortcut == shortcut ? Color(hex: HermesConstants.primaryAccentColor) : Color.clear)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(currentShortcut == shortcut ? Color(hex: HermesConstants.primaryAccentColor) : Color(NSColor.tertiaryLabelColor), lineWidth: 1.5)
                            .frame(width: 16, height: 16)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(shortcut)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func keyVisualizationRow(isPressed: Bool) -> some View {
        HStack(spacing: 6) {
            let hotkey = userSettings.keyboardShortcuts.globalDictationHotkey
            
            // Display modifier keys first
            ForEach(Array(hotkey.modifiers.sorted(by: { $0.sortOrder < $1.sortOrder })), id: \.self) { modifier in
                individualKeyView(modifier: modifier, isPressed: isPressed)
            }
            
            // Display main key with icon and/or text
            individualKeyView(key: hotkey.key, isPressed: isPressed)
        }
    }
    
    // For modifier keys (icon + text)
    private func individualKeyView(modifier: KeyboardModifier, isPressed: Bool) -> some View {
        ZStack {
            keyBackground(isPressed: isPressed)
            
            VStack(spacing: 0) {
                Text(modifier.symbol)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(isPressed ? .white : .primary)
                
                Text(modifier.displayText)
                    .font(.system(size: 6, weight: .medium, design: .monospaced))
                    .foregroundColor(isPressed ? .white : .primary)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    // For main keys (icon and/or text)
    private func individualKeyView(key: KeyboardKey, isPressed: Bool) -> some View {
        ZStack {
            keyBackground(isPressed: isPressed)
            
            if let icon = key.displayIcon, let text = key.displayText {
                // Show both icon and text
                VStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(isPressed ? .white : .primary)
                    
                    Text(text)
                        .font(.system(size: 6, weight: .medium, design: .monospaced))
                        .foregroundColor(isPressed ? .white : .primary)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            } else {
                // Show just the symbol
                Text(key.symbol)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isPressed ? .white : .primary)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 3)
            }
        }
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    // Shared key background styling with realistic key shadows
    private func keyBackground(isPressed: Bool) -> some View {
        let backgroundColor = isPressed ? Color(hex: HermesConstants.primaryAccentColor) : Color(NSColor.controlBackgroundColor)
        print("🎨 Key background rendered as \(isPressed ? "PRESSED (green)" : "normal")")
        
        return RoundedRectangle(cornerRadius: 4)
            .fill(backgroundColor)
            .frame(width: 36, height: 36)
            .onAppear {
                if isPressed {
                    print("🎨 Key background rendered as PRESSED (green)")
                } else {
                    print("🎨 Key background rendered as NOT PRESSED (normal)")
                }
            }
            .overlay(
                // Top/left highlight for 3D effect
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                // Strong bottom-right shadow for 3D key effect
                color: .black.opacity(0.4),
                radius: 0,
                x: 2,
                y: 2
            )
            .shadow(
                // Additional softer shadow
                color: .black.opacity(0.2),
                radius: 1,
                x: 1,
                y: 1
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
    }
    
    
    
}

private struct MicrophoneTestView: View {
    let onContinue: () -> Void
    @State private var isRecording = false
    @State private var audioLevel: Double = 0.0
    @State private var hasRecorded = false
    @State private var selectedMicrophone = "Built-in Microphone"
    
    private let availableMicrophones = [
        "Built-in Microphone",
        "External USB Microphone",
        "AirPods Pro",
        "Studio Microphone"
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            // Title
            VStack(spacing: 12) {
                Text("Test your microphone")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Confirm audio is working and select your preferred input source")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Microphone selection
            VStack(spacing: 20) {
                HermesDropdown(
                    title: "Audio input source:",
                    selection: $selectedMicrophone,
                    options: availableMicrophones,
                    placeholder: "Select microphone"
                )
                .frame(width: 300)
                .onChange(of: selectedMicrophone) {
                    hasRecorded = false // Reset test when changing mic
                }
                
                // Large microphone visualization
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.1) : Color(NSColor.controlBackgroundColor))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isRecording ? 1.0 + audioLevel * 0.3 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: audioLevel)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(isRecording ? Color(hex: HermesConstants.primaryAccentColor) : .secondary)
                    }
                    
                    // Audio level bars
                    HStack(spacing: 6) {
                        ForEach(0..<7) { index in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(audioLevel > Double(index) * 0.15 ? Color(hex: HermesConstants.primaryAccentColor) : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: CGFloat(16 + index * 6))
                                .animation(.easeInOut(duration: 0.1), value: audioLevel)
                        }
                    }
                    
                    Text(isRecording ? "Listening..." : hasRecorded ? "Perfect! Audio is working." : "Click 'Test Audio' to check your microphone")
                        .font(.body)
                        .foregroundColor(hasRecorded ? Color(hex: HermesConstants.primaryAccentColor) : .secondary)
                        .fontWeight(hasRecorded ? .semibold : .regular)
                        .multilineTextAlignment(.center)
                        .frame(width: 300)
                }
            }
            
            // Control buttons
            VStack(spacing: 12) {
                Button(isRecording ? "Stop Test" : "Test Audio") {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
                .primaryButtonStyle(isEnabled: !isRecording || true)
                
                if hasRecorded {
                    Button("Continue") {
                        onContinue()
                    }
                    .primaryButtonStyle()
                } else {
                    Button("Skip Test") {
                        onContinue()
                    }
                    .secondaryButtonStyle()
                }
            }
        }
    }
    
    private func startRecording() {
        isRecording = true
        hasRecorded = false
        
        // Simulate audio level animation
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if isRecording {
                audioLevel = Double.random(in: 0.2...1.0)
            } else {
                audioLevel = 0.0
                timer.invalidate()
            }
        }
        
        // Auto-stop after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if isRecording {
                stopRecording()
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        hasRecorded = true
        audioLevel = 0.0
    }
}

private struct LanguageSelectionView: View {
    let onContinue: () -> Void
    @State private var selectedLanguages: Set<String> = ["English (US)"]
    
    private let languages = [
        "English (US)",
        "English (UK)", 
        "Spanish",
        "French",
        "German",
        "Italian",
        "Portuguese",
        "Japanese",
        "Korean",
        "Chinese (Simplified)",
        "Chinese (Traditional)",
        "Dutch",
        "Russian",
        "Arabic",
        "Hindi"
    ]
    
    var body: some View {
        HStack(spacing: 80) {
            // Left side - language selection
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose your languages")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("(Optional)")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Select the languages you'll be dictating in. This helps us optimize accuracy for your use case.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(width: 400)
                    
                    // Language selection - scrollable multi-select
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Languages (\(selectedLanguages.count) selected):")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(Array(languages.enumerated()), id: \.offset) { index, language in
                                    languageOption(language, isSelected: selectedLanguages.contains(language)) {
                                        if selectedLanguages.contains(language) {
                                            selectedLanguages.remove(language)
                                        } else {
                                            selectedLanguages.insert(language)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .frame(width: 380, height: 220)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(12)
                        
                        Text("Hermes supports 50+ languages with high accuracy transcription. You can change this anytime in settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 380)
                    }
                    
                    VStack(spacing: 10) {
                        Button("Continue") {
                            onContinue()
                        }
                        .primaryButtonStyle()
                        
                        Button("Skip") {
                            onContinue()
                        }
                        .secondaryButtonStyle()
                    }
                }
            }
            
            // Right side - language information (vertically centered)
            VStack {
                Spacer()
                languageVisualization
                Spacer()
            }
        }
    }
    
    private var languageVisualization: some View {
        VStack(spacing: 20) {
            Text("Multi-language support")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Language feature
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("50+ Languages")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("High accuracy worldwide")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Accuracy feature
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("97% Accuracy")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Optimized for each language")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Switch feature
                HStack(spacing: 12) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Easy Switching")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Change anytime in settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .frame(width: 240)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .frame(width: 280)
    }
    
    private func languageOption(_ language: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(language)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color(hex: HermesConstants.primaryAccentColor) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SetUpStepView()
        .environmentObject(OnboardingCoordinator(
            currentStep: .constant(.setUp),
            showingOnboarding: .constant(true)
        ))
        .frame(width: 1000, height: 700)
}