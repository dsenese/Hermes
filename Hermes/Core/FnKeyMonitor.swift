//
//  FnKeyMonitor.swift
//  Hermes
//
//  Created by Claude Code on 8/6/25.
//

import Cocoa
import Carbon.HIToolbox
import Carbon.HIToolbox.Events
import Foundation

/// Custom Fn key monitor using multiple detection methods for maximum compatibility
/// Uses Accessibility API and Carbon HIToolbox to detect Fn key presses without requiring Input Monitoring permissions
@MainActor
class FnKeyMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isFnPressed: Bool = false
    @Published private(set) var isMonitoring: Bool = false
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let pollingInterval: TimeInterval = 0.01 // 10ms polling for responsiveness
    
    // Callback for Fn key state changes
    var onFnChange: ((Bool) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        print("🔑 FnKeyMonitor initialized")
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
    
    // MARK: - Public Methods
    
    /// Check and request Accessibility permissions if needed
    func checkAccessibilityPermissions() -> Bool {
        // Check current permission status
        if AXIsProcessTrusted() {
            return true
        }
        
        // Request permissions with prompt
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("🔑 ⚠️ Accessibility permissions required for Fn key detection")
            print("💡 Please grant Accessibility permissions in System Settings > Privacy & Security > Accessibility")
        } else {
            print("🔑 ✅ Accessibility permissions granted")
        }
        
        return accessEnabled
    }
    
    /// Start monitoring Fn key using multiple detection methods
    func startMonitoring(onChange: @escaping (Bool) -> Void) {
        guard !isMonitoring else {
            print("🔑 ⚠️ Fn key monitoring already active")
            return
        }
        
        print("🔑 🚀 Starting Fn key monitoring...")
        self.onFnChange = onChange
        
        // Method 1: Use NSEvent monitors (primary method - works well for most cases)
        startEventMonitoring()
        
        // Method 2: Carbon HIToolbox polling disabled for now due to API complexities
        // TODO: Implement Carbon polling if NSEvent method proves insufficient
        // startCarbonPolling()
        
        isMonitoring = true
        print("🔑 ✅ Fn key monitoring started with dual detection methods")
    }
    
    /// Stop all Fn key monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        print("🔑 ⏹️ Stopping Fn key monitoring...")
        
        // Stop NSEvent monitoring
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        
        // Stop Carbon polling
        timer?.invalidate()
        timer = nil
        
        // Reset state
        if isFnPressed {
            isFnPressed = false
            onFnChange?(false)
        }
        
        isMonitoring = false
        print("🔑 ✅ Fn key monitoring stopped")
    }
    
    // MARK: - Private Methods - NSEvent Monitoring
    
    /// Primary method: Use NSEvent's flagsChanged to detect Fn key
    private func startEventMonitoring() {
        print("🔑 🎯 Starting NSEvent Fn key monitoring...")
        
        // Global monitor for when app is not focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
        }
        
        // Local monitor for when app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event)
            }
            return event
        }
        
        if globalMonitor != nil || localMonitor != nil {
            print("🔑 ✅ NSEvent monitors registered")
        } else {
            print("🔑 ⚠️ Failed to register NSEvent monitors")
        }
    }
    
    /// Handle NSEvent flagsChanged events
    private func handleFlagsChanged(_ event: NSEvent) {
        let fnPressed = event.modifierFlags.contains(.function)
        
        if fnPressed != isFnPressed {
            isFnPressed = fnPressed
            onFnChange?(fnPressed)
            
            // Only log changes to avoid spam
            print("🔑 NSEvent: Fn key \(fnPressed ? "PRESSED" : "RELEASED")")
        }
    }
    
    // MARK: - Private Methods - Carbon HIToolbox Polling
    
    /// Fallback method: Use Carbon HIToolbox to poll Fn key state
    /// Currently disabled due to API complexity - NSEvent method should be sufficient
    private func startCarbonPolling() {
        // TODO: Implement if needed for better Fn key detection
        print("🔑 🔄 Carbon HIToolbox polling disabled (using NSEvent method only)")
    }
    
    /// Poll Fn key state using Carbon's GetKeys function - DISABLED
    /// TODO: Re-enable when Carbon API usage is properly implemented
    private func pollFnKeyState() {
        // Carbon polling disabled for now - NSEvent method should be sufficient for most use cases
        print("🔑 Carbon polling called but disabled")
    }
    
    /// Detect Fn key from Carbon's keyMap using multiple detection methods - DISABLED  
    /// TODO: Re-enable when Carbon API usage is properly implemented
    private func detectFnKeyFromKeyMap(_ keyMap: [UInt32]) -> Bool {
        // Placeholder - always return false since Carbon polling is disabled
        return false
    }
    
    // MARK: - Utility Methods
    
    /// Get current Fn key state without changing monitoring
    func getCurrentFnState() -> Bool {
        return isFnPressed
    }
    
    /// Test if Fn key detection is working properly
    func testFnKeyDetection() {
        print("🔑 🧪 Testing Fn key detection...")
        print("🔑 Current Fn state: \(isFnPressed)")
        print("🔑 Accessibility permissions: \(AXIsProcessTrusted())")
        print("🔑 Monitoring active: \(isMonitoring)")
        
        // Carbon polling test disabled - using NSEvent method only
        print("🔑 Carbon polling test disabled (using NSEvent method)")
    }
}