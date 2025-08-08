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
    @StateObject private var servicesManager = ServicesManager.shared
    @State private var showingCustomization = false
    @State private var showingTestDialog = false
    @State private var keyPressed = false
    @State private var keyTestPassed = false
    @State private var currentShortcut = ""
    @State private var isListeningForKey = false
    @State private var globalKeyMonitor: Any?
    @State private var pendingShortcut: HotkeyConfiguration?
    @State private var localKeyMonitor: Any?
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
                    Text("We recommend fn")
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
                        
                        // Display keys separately - Services shortcuts are user-assigned
                        keyVisualizationRow(isPressed: keyPressed)
                        
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
            // Set current shortcut from settings - should be "fn" by default
            let hotkeyConfig = userSettings.keyboardShortcuts.globalDictationHotkey
            currentShortcut = hotkeyConfig.displayString
            print("🔧 Onboarding loaded with hotkey: \(hotkeyConfig.displayString)")
            
            // Start monitoring for key presses to show visual feedback
            startKeyMonitoring()
            
            // Show the test dialog after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingTestDialog = true
                }
            }
        }
        .onDisappear {
            // Only stop onboarding key monitoring, not global monitoring
            stopKeyMonitoring()
            print("🔧 Onboarding: Stopped local key monitoring (global monitoring remains active)")
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
                // Display keys as separate visual elements - Services shortcuts are user-assigned  
                keyVisualizationRow(isPressed: keyPressed)
                
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
                    
                    // Save and automatically configure the Services shortcut
                    Task {
                        await userSettings.updateKeyboardShortcut(userSettings.keyboardShortcuts.globalDictationHotkey)
                        
                        // Also notify AppDelegate to update global hotkey registration
                        NotificationCenter.default.post(name: .updateGlobalHotkey, object: userSettings.keyboardShortcuts.globalDictationHotkey)
                        
                        onContinue()
                    }
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
                        shortcutOption("fn", description: "Function key (recommended)")
                        shortcutOption("⌥ Space", description: "Option + Space")
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
                    ) { newHotkey in
                        // Store the pending shortcut but don't save yet
                        pendingShortcut = newHotkey
                        currentShortcut = newHotkey.displayString
                        print("🔧 Custom shortcut pending: \(newHotkey.displayString) (modifiers: \(newHotkey.modifiers), key: \(newHotkey.key))")
                    }
                }
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    // Discard pending shortcut and revert to current
                    pendingShortcut = nil
                    currentShortcut = userSettings.keyboardShortcuts.globalDictationHotkey.displayString
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingCustomization = false
                        showingTestDialog = true
                    }
                }
                .secondaryButtonStyle()
                
                Button("Save") {
                    // Save the pending shortcut if it exists, otherwise keep current
                    let shortcutToSave = pendingShortcut ?? userSettings.keyboardShortcuts.globalDictationHotkey
                    
                    Task {
                        print("💾 Saving shortcut: \(shortcutToSave.displayString)")
                        await userSettings.updateKeyboardShortcut(shortcutToSave)
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingCustomization = false
                            showingTestDialog = true
                        }
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
            
            // Save and automatically configure the Services shortcut
            Task {
                await userSettings.updateKeyboardShortcut(newHotkey)
                print("🔧 Updated hotkey to: \(newHotkey.displayString)")
            }
            
            // Tell the AppDelegate to update its hotkey registration
            NotificationCenter.default.post(name: .updateGlobalHotkey, object: newHotkey)
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
        .plainHoverButtonStyle()
    }
    
    private func keyVisualizationRow(isPressed: Bool) -> some View {
        HStack(spacing: 6) {
            let hotkey = userSettings.keyboardShortcuts.globalDictationHotkey
            
            // Display modifier keys first
            ForEach(Array(hotkey.modifiers.sorted(by: { $0.sortOrder < $1.sortOrder })), id: \.self) { modifier in
                individualKeyView(modifier: modifier, isPressed: isPressed)
            }
            
            // Display main key
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
    
    // MARK: - Key Monitoring Methods
    
    private func startKeyMonitoring() {
        print("🔍 Starting key monitoring for visual feedback")
        
        // Stop any existing monitors
        stopKeyMonitoring()
        
        // Monitor for key events to show visual feedback
        // Use global monitor to capture keys even when not focused
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            self.handleKeyEvent(event)
        }
        
        // Also add local monitor for when app is focused
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            self.handleKeyEvent(event)
            return event
        }
    }
    
    private func stopKeyMonitoring() {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        print("🛑 Stopped key monitoring")
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        let hotkeyConfig = userSettings.keyboardShortcuts.globalDictationHotkey
        
        if event.type == .keyDown {
            // Check if the pressed key matches our hotkey
            if matchesHotkey(event: event, config: hotkeyConfig) {
                // Only trigger once per press (avoid key repeat)
                if !keyPressed {
                    keyPressed = true
                    print("✅ Hotkey pressed: \(hotkeyConfig.displayString)")
                }
            }
        } else if event.type == .keyUp {
            // Check if this is the release of our hotkey
            if keyPressed && matchesHotkey(event: event, config: hotkeyConfig) {
                keyPressed = false
                print("✅ Hotkey released: \(hotkeyConfig.displayString)")
            }
        } else if event.type == .flagsChanged {
            // Handle special cases like fn key or double-tap shortcuts
            if hotkeyConfig.key == .fn && hotkeyConfig.modifiers.isEmpty {
                // Check for fn key
                let wasPressedBefore = keyPressed
                keyPressed = event.modifierFlags.contains(.function)
                if keyPressed && !wasPressedBefore {
                    print("✅ Hotkey pressed: \(hotkeyConfig.displayString)")
                } else if !keyPressed && wasPressedBefore {
                    print("✅ Hotkey released: \(hotkeyConfig.displayString)")
                }
            } else {
                // For all other shortcuts, modifiers alone should NOT trigger
                // Only highlight when the complete combination is pressed
                keyPressed = false
            }
        }
    }
    
    private func matchesHotkey(event: NSEvent, config: HotkeyConfiguration) -> Bool {
        // Check modifiers
        let eventModifiers = extractModifiers(from: event.modifierFlags)
        if eventModifiers != config.modifiers {
            return false
        }
        
        // Check key
        if let mappedKey = mapKeyCodeToKey(event.keyCode) {
            return mappedKey == config.key
        }
        
        return false
    }
    
    private func extractModifiers(from flags: NSEvent.ModifierFlags) -> Set<KeyboardModifier> {
        var modifiers: Set<KeyboardModifier> = []
        
        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        
        return modifiers
    }
    
    private func mapKeyCodeToKey(_ keyCode: UInt16) -> KeyboardKey? {
        // Map all key codes to our KeyboardKey enum
        switch keyCode {
        case 49: return .space
        case 36: return .enter
        case 48: return .tab
        case 53: return .escape
        case 0: return .a
        case 11: return .b
        case 8: return .c
        case 2: return .d
        case 14: return .e
        case 3: return .f
        case 5: return .g
        case 4: return .h
        case 34: return .i
        case 38: return .j
        case 40: return .k
        case 37: return .l
        case 46: return .m
        case 45: return .n
        case 31: return .o
        case 35: return .p
        case 12: return .q
        case 15: return .r
        case 1: return .s
        case 17: return .t
        case 32: return .u
        case 9: return .v
        case 13: return .w
        case 7: return .x
        case 16: return .y
        case 6: return .z
        case 29: return .zero
        case 18: return .one
        case 19: return .two
        case 20: return .three
        case 21: return .four
        case 23: return .five
        case 22: return .six
        case 26: return .seven
        case 28: return .eight
        case 25: return .nine
        case 122: return .f1
        case 120: return .f2
        case 99: return .f3
        case 118: return .f4
        case 96: return .f5
        case 97: return .f6
        case 98: return .f7
        case 100: return .f8
        case 101: return .f9
        case 109: return .f10
        case 103: return .f11
        case 111: return .f12
        case 55: return .command // Command key when pressed alone
        default: return nil
        }
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