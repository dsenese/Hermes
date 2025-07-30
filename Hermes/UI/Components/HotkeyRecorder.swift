//
//  HotkeyRecorder.swift
//  Hermes
//
//  Created by Claude Code on 7/29/25.
//

import SwiftUI
import AppKit

/// Interactive component for recording keyboard shortcuts
struct HotkeyRecorder: View {
    @Binding var hotkey: HotkeyConfiguration
    @State private var isRecording = false
    @State private var currentKeys: Set<KeyboardModifier> = []
    @State private var currentKey: KeyboardKey?
    @State private var showingConflictWarning = false
    @State private var keyMonitor: Any?
    
    let title: String
    let description: String?
    
    init(title: String, description: String? = nil, hotkey: Binding<HotkeyConfiguration>) {
        self.title = title
        self.description = description
        self._hotkey = hotkey
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Hotkey display/recorder
            HStack(spacing: 12) {
                hotkeyDisplay
                
                Spacer()
                
                recordButton
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isRecording ? 2 : 1)
            )
            
            // Conflict warning
            if showingConflictWarning {
                conflictWarning
            }
        }
        .onDisappear {
            // Clean up key monitoring when view disappears
            removeKeyMonitoring()
        }
    }
    
    // MARK: - UI Components
    
    private var hotkeyDisplay: some View {
        HStack(spacing: 4) {
            if isRecording {
                if currentKeys.isEmpty && currentKey == nil {
                    Text("Press keys...")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    recordingKeysDisplay
                }
            } else {
                finalKeysDisplay
            }
        }
        .font(.system(.body, design: .monospaced))
    }
    
    private var recordingKeysDisplay: some View {
        HStack(spacing: 2) {
            ForEach(Array(currentKeys.sorted(by: { $0.sortOrder < $1.sortOrder })), id: \.self) { modifier in
                keyBadge(modifier.symbol, isHighlighted: true)
            }
            
            if let key = currentKey {
                keyBadge(key.symbol, isHighlighted: true)
            } else if currentKeys.isEmpty {
                Text("Press any key...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    private var finalKeysDisplay: some View {
        HStack(spacing: 2) {
            ForEach(Array(hotkey.modifiers.sorted(by: { $0.sortOrder < $1.sortOrder })), id: \.self) { modifier in
                keyBadge(modifier.symbol)
            }
            keyBadge(hotkey.key.symbol)
        }
    }
    
    private func keyBadge(_ symbol: String, isHighlighted: Bool = false) -> some View {
        Text(symbol)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isHighlighted ? Color(hex: HermesConstants.primaryAccentColor).opacity(0.2) : Color.accentColor.opacity(0.1))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isHighlighted ? Color(hex: HermesConstants.primaryAccentColor) : Color.clear, lineWidth: 1)
            )
    }
    
    private var recordButton: some View {
        Button(action: toggleRecording) {
            Text(isRecording ? "Cancel" : "Record")
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
    
    private var conflictWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text("This shortcut may conflict with system shortcuts")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        if isRecording {
            return Color.accentColor.opacity(0.05)
        }
        return Color(NSColor.controlBackgroundColor).opacity(0.5)
    }
    
    private var borderColor: Color {
        if isRecording {
            return Color.accentColor
        }
        return Color.secondary.opacity(0.3)
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        currentKeys.removeAll()
        currentKey = nil
        showingConflictWarning = false
        
        // Setup global key monitoring
        setupKeyMonitoring()
    }
    
    private func stopRecording() {
        isRecording = false
        removeKeyMonitoring()
        
        // Apply the recorded shortcut if we have a key (modifiers are optional)
        if let key = currentKey {
            let newHotkey = HotkeyConfiguration(
                key: key,
                modifiers: currentKeys,
                description: hotkey.description
            )
            
            hotkey = newHotkey
            checkForConflicts(newHotkey)
            
            // Save to user settings and update global registration
            UserSettings.shared.saveToLocalStorage()
            GlobalHotkeyManager.shared.updateHotkey(newHotkey)
        }
        
        currentKeys.removeAll()
        currentKey = nil
    }
    
    // MARK: - Key Monitoring
    
    private func setupKeyMonitoring() {
        print("🔥 Started key monitoring for hotkey recording")
        
        // Remove existing monitor
        removeKeyMonitoring()
        
        // Create key monitor for key down events
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handleKeyEvent(event)
            return nil // Consume the event
        }
    }
    
    private func removeKeyMonitoring() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        print("🔥 Stopped key monitoring")
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            // Handle modifier keys
            let modifiers = extractModifiers(from: event.modifierFlags)
            currentKeys = modifiers
        } else if event.type == .keyDown {
            // Handle regular keys
            if let key = mapKeyCodeToKey(event.keyCode) {
                currentKey = key
                
                // If we have a complete shortcut, finish recording
                if !currentKeys.isEmpty || key != .escape {
                    completeRecording()
                }
            }
        }
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
        // Map common key codes to our KeyboardKey enum
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
        default: return nil
        }
    }
    
    private func completeRecording() {
        DispatchQueue.main.async {
            stopRecording()
        }
    }
    
    private func checkForConflicts(_ hotkey: HotkeyConfiguration) {
        // Check for common system shortcuts
        let potentialConflicts = [
            HotkeyConfiguration(key: .space, modifiers: [.command], description: "Spotlight"),
            HotkeyConfiguration(key: .tab, modifiers: [.command], description: "App Switcher"),
            HotkeyConfiguration(key: .w, modifiers: [.command], description: "Close Window")
        ]
        
        showingConflictWarning = potentialConflicts.contains { $0.key == hotkey.key && $0.modifiers == hotkey.modifiers }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HotkeyRecorder(
            title: "Global Dictation Shortcut",
            description: "Press this combination to start/stop dictation anywhere",
            hotkey: .constant(HotkeyConfiguration(
                key: .space,
                modifiers: [.command],
                description: "Start/Stop Dictation"
            ))
        )
        
        HotkeyRecorder(
            title: "Quick Format",
            description: "Format selected text",
            hotkey: .constant(HotkeyConfiguration(
                key: .f,
                modifiers: [.command, .shift],
                description: "Quick Format"
            ))
        )
    }
    .padding()
    .frame(width: 400)
}