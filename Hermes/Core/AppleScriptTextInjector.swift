//
//  AppleScriptTextInjector.swift
//  Hermes
//
//  Created by Claude Code on 8/6/25.
//

import Foundation
import AppKit

/// Universal text injection using NSAppleScript + System Events for maximum compatibility
@MainActor
class AppleScriptTextInjector: ObservableObject {
    
    // MARK: - Properties
    
    /// Tracks the last injection attempt for error handling
    private var lastInjectionAttempt: Date = .distantPast
    
    /// Rate limiting to prevent excessive AppleScript calls
    private let minimumInjectionInterval: TimeInterval = 0.05 // 50ms between calls
    
    /// Error tracking for fallback decisions
    private var consecutiveErrors = 0
    private let maxConsecutiveErrors = 3
    
    // MARK: - Public Methods
    
    /// Primary text injection method using NSAppleScript
    func injectText(_ text: String) async -> TextInjectionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Performance tracking
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            if duration > 0.4 {
                print("⚠️ AppleScript injection took \(Int(duration * 1000))ms - exceeding 400ms target")
            } else {
                print("🚀 AppleScript injection completed in \(Int(duration * 1000))ms")
            }
        }
        
        // Rate limiting check
        let now = Date()
        if now.timeIntervalSince(lastInjectionAttempt) < minimumInjectionInterval {
            try? await Task.sleep(nanoseconds: UInt64((minimumInjectionInterval * 1_000_000_000)))
        }
        lastInjectionAttempt = now
        
        // Skip empty text
        guard !text.isEmpty else {
            return .success(message: "Empty text - no injection needed")
        }
        
        // Try AppleScript injection
        let result = await performAppleScriptInjection(text: text)
        
        // Track success/failure for adaptive behavior
        if case .success = result {
            consecutiveErrors = 0
        } else {
            consecutiveErrors += 1
        }
        
        return result
    }
    
    /// Inject text with selection replacement
    func replaceSelectedText(_ newText: String, replacingLength: Int) async -> TextInjectionResult {
        // First select the text to replace
        if replacingLength > 0 {
            let selectResult = await selectPreviousCharacters(count: replacingLength)
            if case .failure = selectResult {
                return selectResult
            }
        }
        
        // Then inject the new text (which will replace the selection)
        return await injectText(newText)
    }
    
    /// Clear/delete text using backspace
    func deleteText(length: Int) async -> TextInjectionResult {
        guard length > 0 else {
            return .success(message: "No text to delete")
        }
        
        // Use backspace key to delete text
        let scriptString = """
        tell application "System Events"
            repeat \(length) times
                key code 51
            end repeat
        end tell
        """
        
        return await executeAppleScript(scriptString, description: "delete \(length) characters")
    }
    
    /// Check if AppleScript injection is likely to work
    var isAvailable: Bool {
        // If we've had too many consecutive errors, consider it unavailable
        return consecutiveErrors < maxConsecutiveErrors
    }
    
    // MARK: - Private Methods
    
    /// Core AppleScript injection implementation
    private func performAppleScriptInjection(text: String) async -> TextInjectionResult {
        // Escape the text for AppleScript
        let escapedText = escapeTextForAppleScript(text)
        
        // Create AppleScript command using System Events
        let scriptString = """
        tell application "System Events"
            keystroke "\(escapedText)"
        end tell
        """
        
        return await executeAppleScript(scriptString, description: "inject text")
    }
    
    /// Select previous characters using shift+left arrow
    private func selectPreviousCharacters(count: Int) async -> TextInjectionResult {
        let scriptString = """
        tell application "System Events"
            repeat \(count) times
                key code 123 using {shift down}
            end repeat
        end tell
        """
        
        return await executeAppleScript(scriptString, description: "select \(count) characters")
    }
    
    /// Execute AppleScript and handle errors
    private func executeAppleScript(_ scriptString: String, description: String) async -> TextInjectionResult {
        guard let script = NSAppleScript(source: scriptString) else {
            return .failure(error: .scriptCreationFailed, message: "Failed to create AppleScript for \(description)")
        }
        
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        
        if let error = error {
            let errorCode = error["NSAppleScriptErrorNumber"] as? Int ?? -1
            let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown AppleScript error"
            
            // Handle specific error codes
            switch errorCode {
            case 1002:
                return .failure(error: .permissionDenied, message: "AppleScript permission denied (Error 1002). Check System Preferences > Security & Privacy > Privacy > Automation.")
            case -1743:
                return .failure(error: .applicationNotFound, message: "System Events not accessible")
            default:
                return .failure(error: .scriptExecutionFailed, message: "AppleScript error \(errorCode): \(errorMessage)")
            }
        }
        
        // Success
        return .success(message: "Successfully executed AppleScript for \(description)")
    }
    
    /// Escape text for safe use in AppleScript strings
    private func escapeTextForAppleScript(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")  // Escape backslashes first
            .replacingOccurrences(of: "\"", with: "\\\"")  // Escape quotes
            .replacingOccurrences(of: "\r", with: "\\r")   // Handle carriage returns
            .replacingOccurrences(of: "\n", with: "\\n")   // Handle newlines
            .replacingOccurrences(of: "\t", with: "\\t")   // Handle tabs
    }
}

// MARK: - Result Types

/// Result of a text injection operation
enum TextInjectionResult {
    case success(message: String)
    case failure(error: TextInjectionError, message: String)
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var isFailure: Bool {
        return !isSuccess
    }
}

/// Specific errors that can occur during text injection
enum TextInjectionError {
    case scriptCreationFailed
    case scriptExecutionFailed
    case permissionDenied
    case applicationNotFound
    case rateLimitExceeded
    
    var localizedDescription: String {
        switch self {
        case .scriptCreationFailed:
            return "Failed to create AppleScript"
        case .scriptExecutionFailed:
            return "AppleScript execution failed"
        case .permissionDenied:
            return "Permission denied for AppleScript automation"
        case .applicationNotFound:
            return "Target application not found or accessible"
        case .rateLimitExceeded:
            return "Too many injection attempts - rate limit exceeded"
        }
    }
}