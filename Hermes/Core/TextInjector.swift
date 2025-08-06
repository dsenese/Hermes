//
//  TextInjector.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import Foundation
import ApplicationServices
import AppKit
import Carbon

/// Handles universal text injection into any macOS application using Accessibility API
@MainActor
class TextInjector: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var currentApplication: String = ""
    
    // MARK: - Dependencies
    private let accessibilityManager = AccessibilityManager.shared
    
    // MARK: - Private Properties
    private var lastInjectedText: String = ""
    private var currentElement: AXUIElement?
    private var insertionPoint: Int = 0
    
    // Performance optimization properties
    private var cachedFocusedElement: AXUIElement?
    private var elementCacheTime: Date = .distantPast
    private let cacheTimeout: TimeInterval = 0.5 // 500ms cache
    
    // App-specific handling
    private let appSpecificHandler = AppSpecificHandler()
    
    // Injection history tracking
    private var injectionHistory: [(text: String, timestamp: Date)] = []
    private let maxHistorySize = 5
    
    // MARK: - Initialization
    init() {
        // AccessibilityManager handles permission checking
    }
    
    // MARK: - Computed Properties
    
    /// Current accessibility permission status
    var isAccessibilityEnabled: Bool {
        return accessibilityManager.isAccessibilityEnabled
    }
    
    // MARK: - Public Methods
    
    /// Checks and requests accessibility permissions
    func requestAccessibilityPermissions() -> Bool {
        Task { @MainActor in
            accessibilityManager.checkPermissions()
        }
        return accessibilityManager.isAccessibilityEnabled
    }
    
    func requestAccessibilityPermissionsWithPrompt() -> Bool {
        return accessibilityManager.requestPermissionsWithPrompt()
    }
    
    /// Replaces the current dictation text with new text
    func replaceCurrentDictation(with text: String) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Performance check - your <400ms target
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            if duration > 0.4 {
                print("⚠️ Text injection took \(Int(duration * 1000))ms - exceeding 400ms target")
            } else {
                print("🚀 Text injection completed in \(Int(duration * 1000))ms")
            }
        }
        
        // Always recheck accessibility status before attempting injection
        let hasAccess = accessibilityManager.isAccessibilityEnabled
        guard hasAccess else {
            print("❌ Accessibility not enabled, cannot inject text (status: \(accessibilityManager.permissionStatus.description))")
            return
        }
        
        print("🔄 Text injection attempt: '\(text.prefix(30))...' in app: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown")")
        
        guard !text.isEmpty else { return }
        
        // Track injection history
        trackInjection(text: text)
        
        // Get injection strategy for current app
        let strategy = getInjectionStrategy()
        
        do {
            // Use strategy-based injection
            try await performInjection(text: text, strategy: strategy)
            lastInjectedText = text
            
        } catch {
            print("❌ Text injection via primary method failed: \(error)")
            print("🔄 Falling back to keyboard simulation...")
            
            // Fallback to keyboard simulation
            await simulateKeyboardInput(text: text)
            lastInjectedText = text
        }
    }
    
    /// Finalizes dictation by ensuring text is properly inserted
    func finalizeDictation(with text: String) async {
        guard !text.isEmpty else { return }
        
        print("🎤 Finalizing dictation with text: '\(text.prefix(50))...'")
        
        // Ensure final text is injected
        await replaceCurrentDictation(with: text)
        
        // Clear state
        lastInjectedText = ""
        currentElement = nil
        insertionPoint = 0
        
        print("✅ Dictation finalized with: \(text.prefix(50))...")
    }
    
    /// Clears any currently injected text
    func clearCurrentDictation() async {
        guard !lastInjectedText.isEmpty else { return }
        
        do {
            let focusedElement = try getFocusedElement()
            try await selectAndDelete(element: focusedElement, text: lastInjectedText)
            lastInjectedText = ""
        } catch {
            print("❌ Failed to clear dictation: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    
    private func getFocusedElement() throws -> AXUIElement {
        // Use cached element if still valid
        let now = Date()
        if now.timeIntervalSince(elementCacheTime) < cacheTimeout,
           let cached = cachedFocusedElement {
            return cached
        }
        
        // Get the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            throw TextInjectorError.noFrontmostApplication
        }
        
        currentApplication = frontmostApp.localizedName ?? "Unknown"
        
        // Get the AX application element
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        // Get the focused element
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else {
            throw TextInjectorError.noFocusedElement
        }
        
        let axElement = (element as! AXUIElement)
        
        // Cache the element
        cachedFocusedElement = axElement
        elementCacheTime = now
        
        return axElement
    }
    
    private func insertText(element: AXUIElement, text: String) async throws {
        // Try different methods for text insertion based on element type
        let elementRole = try getElementRole(element)
        
        switch elementRole {
        case kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole:
            try await insertTextInTextField(element: element, text: text)
        default:
            // Fallback to keyboard simulation for other elements
            await simulateKeyboardInput(text: text)
        }
    }
    
    private func selectAndReplace(element: AXUIElement, oldText: String, newText: String) async throws {
        // Get current value
        var currentValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)
        
        guard result == .success,
              let value = currentValue as? String else {
            // Fallback to keyboard simulation
            await selectPreviousTextAndReplace(oldText: oldText, newText: newText)
            return
        }
        
        // Find the old text in the current value
        guard let range = value.range(of: oldText, options: .backwards) else {
            // Old text not found, just append new text
            try await insertText(element: element, text: newText)
            return
        }
        
        // Create new value by replacing old text
        let newValue = value.replacingCharacters(in: range, with: newText)
        
        // Set the new value
        let newValueRef = newValue as CFString
        let setResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValueRef)
        
        if setResult != .success {
            print("⚠️ Direct value replacement failed, trying selection method")
            await selectPreviousTextAndReplace(oldText: oldText, newText: newText)
        }
    }
    
    private func selectAndDelete(element: AXUIElement, text: String) async throws {
        // Try to select the text and delete it
        await selectPreviousTextAndReplace(oldText: text, newText: "")
    }
    
    private func insertTextInTextField(element: AXUIElement, text: String) async throws {
        // Get current insertion point
        var insertionPoint: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXInsertionPointLineNumberAttribute as CFString, &insertionPoint)
        
        // Insert text at current position
        let textRef = text as CFString
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, textRef)
        
        if result != .success {
            throw TextInjectorError.textInsertionFailed
        }
    }
    
    private func selectPreviousTextAndReplace(oldText: String, newText: String) async {
        // Use keyboard shortcuts to select previous text
        let oldTextLength = oldText.count
        
        if oldTextLength > 0 {
            // Select previous text by simulating Shift+Left Arrow
            for _ in 0..<oldTextLength {
                simulateKeyPress(keyCode: 123, modifiers: .maskShift) // Left arrow with shift
            }
            
            // Small delay to ensure selection is registered
            do {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            } catch {}
        }
        
        // Type the new text (this will replace selected text)
        if !newText.isEmpty {
            await simulateKeyboardInput(text: newText)
        } else {
            // If new text is empty, just delete selected text
            simulateKeyPress(keyCode: 51, modifiers: []) // Delete key
        }
    }
    
    private func simulateKeyboardInput(text: String) async {
        // Use CGEvent to simulate keyboard input with proper modifier handling
        for character in text {
            if let (keyCode, needsShift) = KeyCodeMapper.getKeyCode(for: character) {
                let flags: CGEventFlags = needsShift ? .maskShift : []
                
                let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
                
                keyDown?.flags = flags
                keyUp?.flags = flags
                
                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)
                
                // Adaptive delay based on character complexity
                let delay = character.isLetter ? 500_000 : 1_000_000 // 0.5ms for letters, 1ms for symbols
                try? await Task.sleep(nanoseconds: UInt64(delay))
            } else {
                // Handle unsupported characters by skipping or using space
                print("⚠️ Unsupported character '\(character)' in keyboard simulation")
            }
        }
    }
    
    private func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        
        keyDown?.flags = modifiers
        keyUp?.flags = modifiers
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func getElementRole(_ element: AXUIElement) throws -> String {
        var role: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        guard result == .success, let roleString = role as? String else {
            return kAXUnknownRole
        }
        
        return roleString
    }
    
    private func getKeyCodeForCharacter(_ character: Character) -> CGKeyCode {
        // Use enhanced character mapping
        return KeyCodeMapper.getKeyCode(for: character)?.keyCode ?? 49 // Default to space
    }
    
    // MARK: - Enhanced Methods
    
    /// Track injection for history and performance analysis
    private func trackInjection(text: String) {
        injectionHistory.append((text: text, timestamp: Date()))
        if injectionHistory.count > maxHistorySize {
            injectionHistory.removeFirst()
        }
    }
    
    /// Get injection strategy for current app
    private func getInjectionStrategy() -> TextInjectionStrategy {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontmostApp.bundleIdentifier else {
            return .adaptive
        }
        
        return appSpecificHandler.getStrategy(for: bundleID)
    }
    
    /// Perform injection based on strategy
    private func performInjection(text: String, strategy: TextInjectionStrategy) async throws {
        switch strategy {
        case .accessibilityOnly:
            try await performAccessibilityInjection(text: text)
        case .clipboardPreferred:
            await performClipboardInjection(text: text)
        case .keyboardSimulation:
            await simulateKeyboardInput(text: text)
        case .adaptive:
            try await performAdaptiveInjection(text: text)
        case .none:
            throw TextInjectorError.unsupportedApplication
        }
    }
    
    /// Perform accessibility-based injection
    private func performAccessibilityInjection(text: String) async throws {
        let focusedElement = try getFocusedElement()
        
        // Check if we need to handle long text
        if text.count > 2000 {
            try await injectLongText(element: focusedElement, text: text)
        } else {
            // If we have previous text, select and replace it
            if !lastInjectedText.isEmpty {
                try await selectAndReplace(element: focusedElement, oldText: lastInjectedText, newText: text)
            } else {
                // First injection, just insert text
                try await insertText(element: focusedElement, text: text)
            }
        }
    }
    
    /// Handle long text injection with chunking
    private func injectLongText(element: AXUIElement, text: String) async throws {
        let chunkSize = 2000
        let totalChunks = (text.count + chunkSize - 1) / chunkSize
        
        print("📝 Injecting long text (\(text.count) chars) in \(totalChunks) chunks")
        
        for i in stride(from: 0, to: text.count, by: chunkSize) {
            let end = min(i + chunkSize, text.count)
            let startIndex = text.index(text.startIndex, offsetBy: i)
            let endIndex = text.index(text.startIndex, offsetBy: end)
            let chunk = String(text[startIndex..<endIndex])
            
            if i == 0 && !lastInjectedText.isEmpty {
                // First chunk - replace previous text
                try await selectAndReplace(element: element, oldText: lastInjectedText, newText: chunk)
            } else {
                // Subsequent chunks - append
                try await insertText(element: element, text: chunk)
            }
            
            // Small delay between chunks
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
    
    /// Perform clipboard-based injection
    private func performClipboardInjection(text: String) async {
        let pasteboard = NSPasteboard.general
        
        // Store current clipboard content
        let originalTypes = pasteboard.types
        let originalContent = originalTypes?.compactMap { type in
            pasteboard.data(forType: type).map { (type, $0) }
        } ?? []
        
        // Set new content
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // If we have previous text, select it first
        if !lastInjectedText.isEmpty {
            await selectPreviousText(lastInjectedText)
        }
        
        // Simulate Cmd+V
        simulateKeyPress(keyCode: 9, modifiers: .maskCommand) // V key with Command
        
        // Restore original clipboard after delay
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            pasteboard.clearContents()
            for (type, data) in originalContent {
                pasteboard.setData(data, forType: type)
            }
        }
    }
    
    /// Perform adaptive injection (tries multiple methods)
    private func performAdaptiveInjection(text: String) async throws {
        do {
            // First try accessibility
            try await performAccessibilityInjection(text: text)
        } catch {
            print("⚠️ Accessibility injection failed, trying clipboard method")
            await performClipboardInjection(text: text)
        }
    }
    
    /// Select previous text using keyboard shortcuts
    private func selectPreviousText(_ text: String) async {
        let textLength = text.count
        
        if textLength > 0 {
            // Select previous text by simulating Shift+Left Arrow
            for _ in 0..<textLength {
                simulateKeyPress(keyCode: 123, modifiers: .maskShift) // Left arrow with shift
            }
            
            // Small delay to ensure selection is registered
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
}

// MARK: - Supporting Classes

/// App-specific text injection strategies
class AppSpecificHandler {
    private let handlers: [String: TextInjectionStrategy] = [
        "com.apple.dt.Xcode": .accessibilityOnly,
        "com.microsoft.VSCode": .clipboardPreferred,
        "com.google.Chrome": .adaptive,
        "com.microsoft.Word": .clipboardPreferred,
        "com.adobe.Photoshop": .none,
        "com.apple.Safari": .adaptive,
        "com.slack.Slack": .adaptive,
        "com.microsoft.teams": .clipboardPreferred
    ]
    
    func getStrategy(for bundleID: String) -> TextInjectionStrategy {
        return handlers[bundleID] ?? .adaptive
    }
}

enum TextInjectionStrategy {
    case accessibilityOnly
    case clipboardPreferred
    case keyboardSimulation
    case adaptive
    case none
}

/// Enhanced key code mapping
struct KeyCodeMapper {
    static let characterMap: [Character: (keyCode: CGKeyCode, shift: Bool)] = [
        // Letters
        "a": (0, false), "A": (0, true),
        "b": (11, false), "B": (11, true),
        "c": (8, false), "C": (8, true),
        "d": (2, false), "D": (2, true),
        "e": (14, false), "E": (14, true),
        "f": (3, false), "F": (3, true),
        "g": (5, false), "G": (5, true),
        "h": (4, false), "H": (4, true),
        "i": (34, false), "I": (34, true),
        "j": (38, false), "J": (38, true),
        "k": (40, false), "K": (40, true),
        "l": (37, false), "L": (37, true),
        "m": (46, false), "M": (46, true),
        "n": (45, false), "N": (45, true),
        "o": (31, false), "O": (31, true),
        "p": (35, false), "P": (35, true),
        "q": (12, false), "Q": (12, true),
        "r": (15, false), "R": (15, true),
        "s": (1, false), "S": (1, true),
        "t": (17, false), "T": (17, true),
        "u": (32, false), "U": (32, true),
        "v": (9, false), "V": (9, true),
        "w": (13, false), "W": (13, true),
        "x": (7, false), "X": (7, true),
        "y": (16, false), "Y": (16, true),
        "z": (6, false), "Z": (6, true),
        
        // Numbers
        "0": (29, false), "1": (18, false), "2": (19, false), "3": (20, false),
        "4": (21, false), "5": (23, false), "6": (22, false), "7": (26, false),
        "8": (28, false), "9": (25, false),
        
        // Special characters
        " ": (49, false),
        "\n": (36, false), // Return key
        "\t": (48, false), // Tab key
        ".": (47, false), "!": (18, true),
        ",": (43, false), "?": (44, true),
        ";": (41, false), ":": (41, true),
        "'": (39, false), "\"": (39, true),
        "-": (27, false), "_": (27, true),
        "=": (24, false), "+": (24, true)
    ]
    
    static func getKeyCode(for character: Character) -> (keyCode: CGKeyCode, shift: Bool)? {
        return characterMap[character]
    }
}

// MARK: - Error Types
enum TextInjectorError: LocalizedError {
    case accessibilityNotEnabled
    case noFrontmostApplication
    case noFocusedElement
    case textInsertionFailed
    case unsupportedApplication
    
    var errorDescription: String? {
        switch self {
        case .accessibilityNotEnabled:
            return "Accessibility access is required for text injection"
        case .noFrontmostApplication:
            return "No frontmost application found"
        case .noFocusedElement:
            return "No focused text element found"
        case .textInsertionFailed:
            return "Failed to insert text"
        case .unsupportedApplication:
            return "Current application does not support text injection"
        }
    }
}