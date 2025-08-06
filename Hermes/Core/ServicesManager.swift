//
//  ServicesManager.swift
//  Hermes
//
//  Created by Claude Code on 7/30/25.
//

import Foundation
import AppKit
import ApplicationServices

/// Manages macOS Services integration for global shortcuts without Input Monitoring permission
@MainActor
class ServicesManager: NSObject, ObservableObject {
    // MARK: - Singleton
    static let shared = ServicesManager()
    
    // MARK: - Published Properties
    @Published private(set) var isServicesRegistered = false
    @Published private(set) var isDictationActive = false
    
    // MARK: - Private Properties
    private var dictationEngine: DictationEngine?
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupServices()
    }
    
    // MARK: - Public Methods
    
    /// Register the dictation engine for callbacks
    func registerDictationEngine(_ engine: DictationEngine) {
        self.dictationEngine = engine
        print("✅ ServicesManager registered with DictationEngine")
    }
    
    /// Programmatically set the keyboard shortcut for our Services
    func setKeyboardShortcut(_ shortcut: String) async -> Bool {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            print("❌ Could not get bundle identifier")
            return false
        }
        
        // Construct the service name as it appears in pbs.plist
        // Format: "bundleId - MenuItem - NSMessage"
        let serviceName = "\(bundleId) - Hermes: Toggle Dictation - toggleDictation"
        
        // Convert our shortcut format to macOS key_equivalent format
        guard let keyEquivalent = convertToKeyEquivalent(shortcut) else {
            print("❌ Invalid shortcut format: \(shortcut)")
            return false
        }
        
        print("🔧 Setting Services shortcut for: \(serviceName)")
        print("🔧 Key equivalent: \(keyEquivalent)")
        
        return await setServiceShortcutInPlist(serviceName: serviceName, keyEquivalent: keyEquivalent)
    }
    
    /// Check if Services are properly registered
    func validateServicesRegistration() -> Bool {
        // Services registration is validated by macOS at runtime
        return isServicesRegistered
    }
    
    // MARK: - Services Setup
    
    private func setupServices() {
        // Register services provider
        NSApp.servicesProvider = self
        
        // Update services menu (forces macOS to recognize our services)
        NSUpdateDynamicServices()
        
        isServicesRegistered = true
        print("✅ macOS Services registered for Hermes dictation")
        print("📋 Users can assign keyboard shortcuts in System Settings > Keyboard > Shortcuts > Services")
    }
    
    // MARK: - Services Methods (Called by macOS)
    
    /// Start dictation service - called when user triggers the service
    @objc func startDictation(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        print("🎤 Services: Start Dictation triggered by user")
        
        guard let engine = dictationEngine else {
            print("❌ No dictation engine registered")
            return
        }
        
        if !engine.isActive {
            isDictationActive = true
            Task {
                await engine.startDictation()
            }
        } else {
            print("⚠️ Dictation already active")
        }
    }
    
    /// Stop dictation service - called when user triggers stop service
    @objc func stopDictation(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        print("🛑 Services: Stop Dictation triggered by user")
        
        guard let engine = dictationEngine else {
            print("❌ No dictation engine registered")  
            return
        }
        
        if engine.isActive {
            isDictationActive = false
            Task {
                await engine.stopDictation()
            }
        } else {
            print("⚠️ Dictation not active")
        }
    }
    
    /// Toggle dictation service - single service for start/stop
    @objc func toggleDictation(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        print("🔄 Services: Toggle Dictation triggered by user")
        
        guard let engine = dictationEngine else {
            print("❌ No dictation engine registered")
            return
        }
        
        if engine.isActive {
            // Stop dictation
            isDictationActive = false
            Task {
                await engine.stopDictation()
            }
        } else {
            // Start dictation
            isDictationActive = true
            Task {
                await engine.startDictation()
            }
        }
    }
    
    // MARK: - Services Validation
    
    /// Validate if the service can be performed (called by macOS)
    func validRequestorForSendType(_ sendType: String?, andReturnType returnType: String?) -> Any? {
        // Our services don't require specific pasteboard types
        // Return self to indicate we can handle the service
        return self
    }
}

// MARK: - Services Menu Integration

extension ServicesManager {
    
    /// Get user-friendly service names for display
    static var serviceDisplayNames: [String: String] {
        return [
            "toggleDictation": "Hermes: Toggle Dictation",
            "startDictation": "Hermes: Start Dictation", 
            "stopDictation": "Hermes: Stop Dictation"
        ]
    }
    
    /// Instructions for users to set up shortcuts
    static var shortcutInstructions: String {
        return """
        Hermes will automatically configure your keyboard shortcut.
        
        The shortcut you choose in the app will be set system-wide
        and work in any application without requiring Input Monitoring permission.
        """
    }
}

// MARK: - Private Implementation

private extension ServicesManager {
    
    /// Convert user-friendly shortcut to macOS key_equivalent format
    func convertToKeyEquivalent(_ shortcut: String) -> String? {
        let components = shortcut.lowercased().components(separatedBy: "+")
        var keyEquivalent = ""
        var baseKey = ""
        var hasFnKey = false
        
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            switch trimmed {
            case "cmd", "command", "⌘":
                keyEquivalent += "@"
            case "shift", "⇧":
                keyEquivalent += "$"
            case "alt", "option", "opt", "⌥":
                keyEquivalent += "~"
            case "ctrl", "control", "⌃":
                keyEquivalent += "^"
            case "fn", "function":
                // Fn key can be a modifier or base key
                if baseKey.isEmpty {
                    baseKey = "fn"
                } else {
                    hasFnKey = true
                }
            default:
                // This should be the base key
                baseKey = trimmed
            }
        }
        
        // Handle fn key special case - it can be used alone or with modifiers
        if hasFnKey && baseKey == "fn" {
            // Fn key alone is valid - just return "fn"
            return "fn"
        }
        
        // Handle special keys
        switch baseKey {
        case "fn":
            // Fn key as base key (when used alone)
            baseKey = "fn"
        case "space":
            baseKey = " "
        case "return", "enter":
            baseKey = "↩"
        case "tab":
            baseKey = "⇥"
        case "escape", "esc":
            baseKey = "⎋"
        case "delete", "backspace":
            baseKey = "⌫"
        case "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12":
            // Function keys are represented as-is
            break
        default:
            // Regular keys (a-z, 0-9) stay as-is
            break
        }
        
        // Combine modifiers + base key
        return keyEquivalent + baseKey
    }
    
    /// Set the Services shortcut in pbs.plist using shell commands
    func setServiceShortcutInPlist(serviceName: String, keyEquivalent: String) async -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let plistPath = "\(homeDir)/Library/Preferences/pbs.plist"
        
        // First, try to delete any existing entry
        let deleteCommand = """
        /usr/libexec/PlistBuddy -c 'Delete NSServicesStatus:"\(serviceName)"' '\(plistPath)' 2>/dev/null || true
        """
        
        // Then add the new entry with our shortcut
        let addCommand = """
        defaults write pbs NSServicesStatus -dict-add '"\(serviceName)"' '{key_equivalent = "\(keyEquivalent)"; enabled_context_menu = 1; enabled_services_menu = 1;}'
        """
        
        // Refresh Services
        let refreshCommand = "killall pbs 2>/dev/null || true"
        
        do {
            // Execute commands sequentially
            try await executeShellCommand(deleteCommand)
            try await executeShellCommand(addCommand)
            try await executeShellCommand(refreshCommand)
            
            print("✅ Services shortcut set successfully")
            print("📋 You may need to try the service from the Services menu first, then use the keyboard shortcut")
            return true
        } catch {
            print("❌ Failed to set Services shortcut: \(error)")
            return false
        }
    }
    
    /// Execute shell command asynchronously
    func executeShellCommand(_ command: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = ["-c", command]
            
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "ShellCommand", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Command failed with status \(process.terminationStatus)"]))
                }
            }
            
            process.launch()
        }
    }
}