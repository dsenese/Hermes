//
//  GlobalShortcutManager.swift
//  Hermes
//
//  Created by Claude Code on 7/30/25.
//

import Foundation
import AppKit
import HotKey

/// Global shortcut manager using HotKey library for proper system-wide hotkeys
/// Works without Input Monitoring permissions using Carbon APIs
@MainActor
class GlobalShortcutManager: NSObject {
    static let shared = GlobalShortcutManager()
    
    // MARK: - Dependencies
    private var accessibilityManager: AccessibilityManager {
        return AccessibilityManager.shared
    }
    
    // MARK: - Private Properties
    private var registeredHotKeys: [String: HotKey] = [:]
    private var isDictating = false
    
    
    private override init() {
        super.init()
        print("🔧 GlobalShortcutManager: Initializing HotKey-based manager")
    }
    
    // MARK: - Registration Methods
    
    /// Register a global shortcut using HotKey library
    func register(_ accelerator: String, callback: @escaping () -> Void) -> Bool {
        print("🔧 GlobalShortcutManager: Registering hotkey '\(accelerator)'")
        
        // First unregister if already exists
        if let existingHotKey = registeredHotKeys[accelerator] {
            existingHotKey.keyDownHandler = nil
            existingHotKey.keyUpHandler = nil
            registeredHotKeys.removeValue(forKey: accelerator)
        }
        
        
        // Create HotKey instance for regular key combinations
        guard let hotKey = createHotKey(for: accelerator) else {
            print("❌ Failed to create HotKey for '\(accelerator)'")
            return false
        }
        
        // Set up hold-to-dictate handlers
        hotKey.keyDownHandler = { [weak self] in
            self?.handleKeyDown(for: accelerator)
        }
        
        hotKey.keyUpHandler = { [weak self] in
            self?.handleKeyUp(for: accelerator)
        }
        
        registeredHotKeys[accelerator] = hotKey
        print("✅ Successfully registered global hotkey '\(accelerator)'")
        return true
    }
    
    /// Unregister a specific shortcut
    func unregister(_ accelerator: String) -> Bool {
        // Handle regular hotkeys
        guard let hotKey = registeredHotKeys[accelerator] else {
            print("⚠️ Hotkey '\(accelerator)' not registered")
            return false
        }
        
        hotKey.keyDownHandler = nil
        hotKey.keyUpHandler = nil
        registeredHotKeys.removeValue(forKey: accelerator)
        print("✅ Unregistered hotkey '\(accelerator)'")
        
        return true
    }
    
    /// Unregister all shortcuts
    func unregisterAll() {
        print("🔄 Unregistering all hotkeys...")
        
        // Clean up regular hotkeys
        for (_, hotKey) in registeredHotKeys {
            hotKey.keyDownHandler = nil
            hotKey.keyUpHandler = nil
        }
        registeredHotKeys.removeAll()
        
        
        print("✅ All hotkeys unregistered")
    }
    
    /// Retry setup (for compatibility)
    func retrySetup() {
        print("🔄 GlobalShortcutManager: Retrying setup")
        // HotKey library handles registration automatically, no manual setup needed
    }
    
    /// Check if monitoring is active
    var isMonitoringActive: Bool {
        return !registeredHotKeys.isEmpty
    }
    
    // MARK: - HotKey Creation and Handling
    
    /// Create a HotKey instance using the library's built-in parsing
    private func createHotKey(for accelerator: String) -> HotKey? {
        // Try simple key first using the library's built-in parser
        if let key = Key(string: accelerator) {
            print("✅ Created HotKey for '\(accelerator)' using library parser")
            return HotKey(key: key, modifiers: [])
        }
        
        // Handle modifier combinations with Unicode symbols
        var modifiers: NSEvent.ModifierFlags = []
        var baseKey = accelerator
        
        // Parse Unicode modifier symbols first
        if accelerator.contains("⌃") {
            modifiers.insert(.control)
            baseKey = baseKey.replacingOccurrences(of: "⌃", with: "")
        }
        if accelerator.contains("⌘") {
            modifiers.insert(.command) 
            baseKey = baseKey.replacingOccurrences(of: "⌘", with: "")
        }
        if accelerator.contains("⌥") {
            modifiers.insert(.option)
            baseKey = baseKey.replacingOccurrences(of: "⌥", with: "")
        }
        if accelerator.contains("⇧") {
            modifiers.insert(.shift)
            baseKey = baseKey.replacingOccurrences(of: "⇧", with: "")
        }
        
        // Parse text modifiers as fallback
        let lowercased = accelerator.lowercased()
        if lowercased.contains("cmd+") || lowercased.contains("command+") {
            modifiers.insert(.command)
            baseKey = baseKey.replacingOccurrences(of: "cmd+", with: "").replacingOccurrences(of: "command+", with: "")
        }
        if lowercased.contains("ctrl+") || lowercased.contains("control+") {
            modifiers.insert(.control)
            baseKey = baseKey.replacingOccurrences(of: "ctrl+", with: "").replacingOccurrences(of: "control+", with: "")
        }
        if lowercased.contains("opt+") || lowercased.contains("option+") {
            modifiers.insert(.option)
            baseKey = baseKey.replacingOccurrences(of: "opt+", with: "").replacingOccurrences(of: "option+", with: "")
        }
        if lowercased.contains("shift+") {
            modifiers.insert(.shift)
            baseKey = baseKey.replacingOccurrences(of: "shift+", with: "")
        }
        if lowercased.contains("fn+") || lowercased.contains("function+") {
            modifiers.insert(.function)
            baseKey = baseKey.replacingOccurrences(of: "fn+", with: "").replacingOccurrences(of: "function+", with: "")
        }
        
        // Clean up the base key and ensure lowercase for library parsing
        baseKey = baseKey.trimmingCharacters(in: .whitespaces).lowercased()
        
        print("🔍 Parsing '\(accelerator)': extracted base key '\(baseKey)' with modifiers \(modifiers)")
        
        // Try to create key with parsed base key
        guard let key = Key(string: baseKey) else {
            print("❌ Unsupported key: '\(accelerator)' - base key '\(baseKey)' not recognized by HotKey library")
            print("💡 Supported keys: \(getSupportedKeys())")
            print("💡 Library supports: \(getLibrarySupportedKeys())")
            return nil
        }
        
        print("✅ Created HotKey for '\(accelerator)' -> Key: \(baseKey), Modifiers: \(modifiers)")
        return HotKey(key: key, modifiers: modifiers)
    }
    
    /// Get list of supported keys for error messages
    private func getSupportedKeys() -> String {
        return "a-z, 0-9, f1-f20, space, return, escape, tab, delete, arrow keys"
    }
    
    /// Test what keys the HotKey library actually supports
    private func getLibrarySupportedKeys() -> String {
        let testKeys = ["a", "s", "f1", "f2", "space", "return", "escape"]
        var supported: [String] = []
        
        for testKey in testKeys {
            if Key(string: testKey) != nil {
                supported.append(testKey)
            }
        }
        
        return supported.joined(separator: ", ")
    }
    
    
    /// Handle key down event
    private func handleKeyDown(for accelerator: String) {
        guard !isDictating else { return }
        
        print("🎙️ Hotkey '\(accelerator)' PRESSED - starting dictation")
        isDictating = true
        startDictation()
    }
    
    /// Handle key up event
    private func handleKeyUp(for accelerator: String) {
        guard isDictating else { return }
        
        print("🛑 Hotkey '\(accelerator)' RELEASED - stopping dictation")
        isDictating = false
        stopDictation()
    }
    
    // MARK: - Dictation Methods
    
    private func startDictation() {
        Task {
            print("🚀 GlobalShortcutManager: Starting dictation session...")
            
            // Check if we're in onboarding
            let userSettings = UserSettings.shared
            if !userSettings.isOnboardingCompleted {
                print("⚠️ GlobalShortcutManager: Onboarding not complete, preventing dictation activation")
                return
            }
            
            // Get the dictation engine
            let dictationEngine = DictationEngine.shared
            
            // Determine context
            let context = determineAppropriateContext()
            print("🌍 GlobalShortcutManager: Using \(context) context for hotkey dictation")
            
            await dictationEngine.startDictation(context: context)
        }
    }
    
    private func stopDictation() {
        Task {
            print("⏹️ GlobalShortcutManager: Stopping dictation session...")
            
            let dictationEngine = DictationEngine.shared
            await dictationEngine.stopDictation()
        }
    }
    
    private func determineAppropriateContext() -> DictationContext {
        // Check if Hermes is the active app
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let hermesBundle = Bundle.main.bundleIdentifier else {
            return .global
        }
        
        if frontmostApp.bundleIdentifier == hermesBundle {
            print("📱 Hermes is active - using local context for Notes integration")
            return .local
        } else {
            print("🌐 External app (\(frontmostApp.localizedName ?? "Unknown")) is active - using global context")
            return .global
        }
    }
    
    deinit {
        // Clean up all hotkeys on deallocation
        for (_, hotKey) in registeredHotKeys {
            hotKey.keyDownHandler = nil
            hotKey.keyUpHandler = nil
        }
        registeredHotKeys.removeAll()
        
    }
}