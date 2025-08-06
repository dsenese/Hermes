//
//  KeyboardShortcutCustomizationView.swift
//  Hermes
//
//  Created by Claude Code on 8/5/25.
//

import SwiftUI

/// Reusable keyboard shortcut customization view that can be used in onboarding or settings
struct KeyboardShortcutCustomizationView: View {
    @EnvironmentObject private var userSettings: UserSettings
    @State private var currentShortcut: String = ""
    @State private var pendingShortcut: HotkeyConfiguration?
    
    let onSave: () -> Void
    let onCancel: () -> Void
    let isMainApp: Bool // true if shown in main app, false if in onboarding
    
    init(onSave: @escaping () -> Void, onCancel: @escaping () -> Void, isMainApp: Bool = false) {
        self.onSave = onSave
        self.onCancel = onCancel
        self.isMainApp = isMainApp
    }
    
    var body: some View {
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
                    onCancel()
                }
                .secondaryButtonStyle()
                
                Button("Save") {
                    // Save the pending shortcut if it exists, otherwise keep current
                    let shortcutToSave = pendingShortcut ?? userSettings.keyboardShortcuts.globalDictationHotkey
                    
                    Task {
                        print("💾 Saving shortcut: \(shortcutToSave.displayString)")
                        await userSettings.updateKeyboardShortcut(shortcutToSave)
                        onSave()
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
        .frame(maxWidth: isMainApp ? 600 : 500) // Slightly wider in main app
        .onAppear {
            // Load current shortcut
            let hotkeyConfig = userSettings.keyboardShortcuts.globalDictationHotkey
            currentShortcut = hotkeyConfig.displayString
        }
    }
    
    /// Create a shortcut option button
    private func shortcutOption(_ keys: String, description: String) -> some View {
        Button(action: {
            if let shortcut = createHotkeyFromDisplayString(keys) {
                pendingShortcut = shortcut
                currentShortcut = keys
                print("🔧 Preset shortcut selected: \(keys)")
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(keys)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if currentShortcut == keys {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                        .font(.system(size: 20))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(currentShortcut == keys ? 
                         Color(hex: HermesConstants.primaryAccentColor).opacity(0.1) : 
                         Color(NSColor.quaternarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(currentShortcut == keys ? 
                           Color(hex: HermesConstants.primaryAccentColor) : 
                           Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: currentShortcut)
    }
    
    /// Create HotkeyConfiguration from display string
    private func createHotkeyFromDisplayString(_ displayString: String) -> HotkeyConfiguration? {
        switch displayString {
        case "fn":
            return HotkeyConfiguration(key: .fn, modifiers: [], description: "Start/Stop Dictation")
        case "⌥ Space":
            return HotkeyConfiguration(key: .space, modifiers: [.option], description: "Start/Stop Dictation")
        case "⌘⌘":
            return HotkeyConfiguration(key: .command, modifiers: [], description: "Start/Stop Dictation")
        case "⌃ Space":
            return HotkeyConfiguration(key: .space, modifiers: [.control], description: "Start/Stop Dictation")
        default:
            return nil
        }
    }
}