//
//  AccessibilityManager.swift
//  Hermes
//
//  Created by Claude Code on 8/4/25.
//

import Foundation
import ApplicationServices
import AppKit

/// Reliable accessibility permission manager that combines API checks with functional testing
class AccessibilityManager: ObservableObject {
    private static var _shared: AccessibilityManager?
    
    @MainActor
    static var shared: AccessibilityManager {
        if let instance = _shared {
            return instance
        }
        let instance = AccessibilityManager()
        _shared = instance
        return instance
    }
    
    // Development bypass - DISABLED for production reliability
    // Only enable this if you're absolutely certain accessibility is working and the API is giving false negatives
    private let DEVELOPMENT_BYPASS_API_CHECK = false
    
    @Published private(set) var isAccessibilityEnabled = false
    @Published private(set) var permissionStatus: PermissionStatus = .unknown
    
    private var pollTimer: Timer?
    private var lastFunctionalTestResult = false
    
    enum PermissionStatus {
        case unknown
        case denied
        case granted
        case inconsistent // API says granted but functionality doesn't work
        
        var description: String {
            switch self {
            case .unknown: return "Unknown"
            case .denied: return "Denied"
            case .granted: return "Granted"
            case .inconsistent: return "Inconsistent (TCC Issue)"
            }
        }
    }
    
    @MainActor
    private init() {
        // Run diagnostic checks on startup
        checkCodeSigningStatus()
        checkPermissions()
    }
    
    @MainActor
    func startMonitoring() {
        checkPermissions()
        
        // Poll every 10 seconds to detect permission changes (less frequent to reduce spam)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                AccessibilityManager.shared.checkPermissions()
            }
        }
    }
    
    @MainActor
    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    /// Comprehensive permission check using both API and functional testing
    @MainActor
    func checkPermissions() {
        let apiCheck = AXIsProcessTrusted()
        let functionalCheck = testAccessibilityFunctionality()
        let eventTapCheck = testEventTapAccess()
        
        
        let wasEnabled = isAccessibilityEnabled
        let oldStatus = permissionStatus
        
        // DEVELOPMENT MODE: Override API checks if we know accessibility is enabled
        if DEVELOPMENT_BYPASS_API_CHECK {
            // Only log this once, not repeatedly
            permissionStatus = .granted
            isAccessibilityEnabled = true
        } else {
            // IMPROVED LOGIC: Prioritize functional test over API since macOS Ventura has bugs with AXIsProcessTrusted
            if functionalCheck {
                // Functional test passed - this is what actually matters for text injection
                permissionStatus = .granted
                isAccessibilityEnabled = true
            } else if eventTapCheck {
                // Event tap test passed - also reliable
                permissionStatus = .granted
                isAccessibilityEnabled = true
            } else if apiCheck {
                // Only API passed but no functional access - might be permission issue
                permissionStatus = .inconsistent
                isAccessibilityEnabled = false
            } else {
                // All tests failed - no permission
                permissionStatus = .denied
                isAccessibilityEnabled = false
            }
        }
        
        // Log status changes
        if wasEnabled != isAccessibilityEnabled || oldStatus != permissionStatus {
            // Notify observers of the change
            NotificationCenter.default.post(name: .accessibilityStateChanged, object: nil)
        }
        
        lastFunctionalTestResult = functionalCheck
    }
    
    /// Test actual accessibility functionality rather than just API permission
    private func testAccessibilityFunctionality() -> Bool {
        // DON'T skip functional test even if API check fails - API can be wrong!
        // During development, AXIsProcessTrusted() often returns false incorrectly
        
        // Test 1: Can we access the frontmost application?
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        let _ = frontmostApp.localizedName ?? "Unknown"
        
        // Test 2: Can we get basic application attributes?
        var appTitle: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(appElement, kAXTitleAttribute as CFString, &appTitle)
        
        // Test 3: Can we access the focused element?
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        // Test 4: Try to get the role of the app element (most basic accessibility test)
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(appElement, kAXRoleAttribute as CFString, &role)
        
        // Test 5: Try to get windows (almost all apps have windows)
        var windows: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)
        
        // Test 6: Most importantly - can we test text injection capability?
        var hasTextInjectionCapability = false
        if focusResult == .success, let focusElement = focusedElement {
            let axElement = (focusElement as! AXUIElement)
            var value: CFTypeRef?
            let valueResult = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &value)
            hasTextInjectionCapability = (valueResult == .success)
        }
        
        
        // If we can do any of these accessibility operations, we have access
        let hasBasicAccess = (titleResult == .success || focusResult == .success || 
                             roleResult == .success || windowsResult == .success || hasTextInjectionCapability)
        
        
        return hasBasicAccess
    }
    
    /// Test accessibility access using CGEventTapCreate (most reliable method)
    private func testEventTapAccess() -> Bool {
        // Create a test event tap - this is the most reliable way to test accessibility permissions
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // Less intrusive than filtering
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, _, _ in nil },
            userInfo: nil
        )
        
        if let tap = eventTap {
            // Successfully created event tap - we have accessibility permissions
            CFMachPortInvalidate(tap)
            return true
        } else {
            // Failed to create event tap - no accessibility permissions
            return false
        }
    }
    
    /// Request accessibility permissions with prompt
    func requestPermissionsWithPrompt() -> Bool {
        
        
        // IMPORTANT: Based on research - AXIsProcessTrustedWithOptions doesn't guarantee immediate functionality
        // There can be a delay in permission propagation even with positive return
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let basicTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        
        // Don't automatically open System Preferences as it can cause issues
        // The AXIsProcessTrustedWithOptions call above will show the system dialog
        
        // Based on research: Give more time for permission propagation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.checkPermissions()
            
            // Additional recheck after longer delay for permission propagation
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.checkPermissions()
            }
        }
        
        return basicTrusted
    }
    
    /// Get code signature information for debugging
    private func getCodeSignatureInfo() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-dv", Bundle.main.bundlePath]
        
        let pipe = Pipe()
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if output.contains("Authority=Apple Development") {
                return "Apple Development Certificate ✅"
            } else if output.contains("adhoc") {
                return "Ad-hoc Signed ⚠️"
            } else {
                return "Unknown Signature"
            }
        } catch {
            return "Signature check failed"
        }
    }
    
    /// Force recheck permissions (useful after user changes system settings)
    @MainActor
    func forceRecheck() {
        checkPermissions()
    }
    
    /// Manual override when user has confirmed accessibility is enabled in System Preferences
    @MainActor
    func confirmAccessibilityEnabled() {
        permissionStatus = .granted
        isAccessibilityEnabled = true
        
        // Recheck after a moment to see if API catches up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkPermissions()
        }
    }
    
    /// Reset and refresh accessibility permissions (based on research recommendations)
    func resetAndRefreshPermissions() {
        
        // First reset TCC permissions
        resetTCCPermissions()
        
        // Wait a moment then request fresh permissions
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Request fresh permissions
            let _ = self.requestPermissionsWithPrompt()
            
            // Instruct user to uncheck/recheck as research suggests
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Reset"
            alert.informativeText = "Please go to System Settings > Privacy & Security > Accessibility and:\n\n1. Uncheck Hermes if it's already listed\n2. Check it again to refresh the system's trust\n\nThis resolves permission caching issues."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openAccessibilityPreferences()
            }
        }
    }
    
    /// Reset TCC permissions for this app
    func resetTCCPermissions() {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return
        }
        
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", "Accessibility", bundleID]
        
        do {
            try task.run()
            task.waitUntilExit()
            
        } catch {
        }
    }
    
    /// Check code signing status and provide diagnostics
    func checkCodeSigningStatus() {
        let appPath = Bundle.main.bundlePath
        
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-dv", "--verbose=4", appPath]
        
        let pipe = Pipe()
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let _ = String(data: data, encoding: .utf8) ?? ""
            
            // Also check entitlements
            checkEntitlements()
            
        } catch {
        }
    }
    
    /// Check app entitlements
    private func checkEntitlements() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-d", "--entitlements", "-", Bundle.main.bundlePath]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let _ = String(data: data, encoding: .utf8) ?? ""
            
        } catch {
        }
    }
    
    /// Open System Preferences to Accessibility settings
    func openAccessibilityPreferences() {
        let prefPane = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: prefPane) {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Get user-friendly error message based on current status
    var statusMessage: String {
        switch permissionStatus {
        case .unknown:
            return "Checking accessibility permissions..."
        case .denied:
            return "Accessibility permission is required for global shortcuts to work"
        case .granted:
            return "Accessibility permissions are working correctly"
        case .inconsistent:
            return "Permission detected but not functional. Try removing and re-adding Hermes in Accessibility settings"
        }
    }
    
    /// Get recommended action for current status
    var recommendedAction: String {
        switch permissionStatus {
        case .unknown:
            return "Please wait..."
        case .denied:
            return "Grant Permission"
        case .granted:
            return "All Good"
        case .inconsistent:
            return "Reset Permission"
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let accessibilityStateChanged = Notification.Name("accessibilityStateChanged")
}