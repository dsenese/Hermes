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
        To set up a global keyboard shortcut for Hermes:
        
        1. Open System Settings > Keyboard > Shortcuts > Services
        2. Find "Hermes: Toggle Dictation" under "Text" services
        3. Click the service and assign your preferred shortcut (e.g., Fn+D)
        4. The shortcut will work system-wide in any application
        
        No Input Monitoring permission required!
        """
    }
}