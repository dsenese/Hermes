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
    @Published private(set) var isAccessibilityEnabled = false
    @Published private(set) var currentApplication: String = ""
    
    // MARK: - Private Properties
    private var lastInjectedText: String = ""
    private var currentElement: AXUIElement?
    private var insertionPoint: Int = 0
    
    // MARK: - Initialization
    init() {
        checkAccessibilityPermissions()
    }
    
    // MARK: - Public Methods
    
    /// Checks and requests accessibility permissions
    func requestAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        isAccessibilityEnabled = trusted
        return trusted
    }
    
    /// Replaces the current dictation text with new text
    func replaceCurrentDictation(with text: String) async {
        guard isAccessibilityEnabled else {
            print("❌ Accessibility not enabled, cannot inject text")
            return
        }
        
        guard !text.isEmpty else { return }
        
        do {
            // Get the currently focused element
            let focusedElement = try getFocusedElement()
            
            // If we have previous text, select and replace it
            if !lastInjectedText.isEmpty {
                try await selectAndReplace(element: focusedElement, oldText: lastInjectedText, newText: text)
            } else {
                // First injection, just insert text
                try await insertText(element: focusedElement, text: text)
            }
            
            lastInjectedText = text
            
        } catch {
            print("❌ Text injection failed: \(error)")
        }
    }
    
    /// Finalizes dictation by ensuring text is properly inserted
    func finalizeDictation(with text: String) async {
        guard !text.isEmpty else { return }
        
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
    
    private func checkAccessibilityPermissions() {
        isAccessibilityEnabled = AXIsProcessTrusted()
        
        if !isAccessibilityEnabled {
            print("⚠️ Accessibility permissions not granted. Please enable in System Preferences > Security & Privacy > Privacy > Accessibility")
        }
    }
    
    private func getFocusedElement() throws -> AXUIElement {
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
        
        return (element as! AXUIElement)
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
        // Use CGEvent to simulate keyboard input
        for character in text {
            let keyCode = getKeyCodeForCharacter(character)
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
            
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            
            // Small delay between keystrokes for reliability
            do {
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            } catch {}
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
        // This is a simplified mapping - in production, you'd want a complete character-to-keycode mapping
        switch character {
        case "a"..."z":
            let ascii = character.asciiValue ?? 97
            return CGKeyCode(ascii - 97)
        case "A"..."Z":
            let ascii = character.asciiValue ?? 65
            return CGKeyCode(ascii - 65)
        case "0"..."9":
            let ascii = character.asciiValue ?? 48
            return CGKeyCode(ascii - 48 + 29)
        case " ":
            return 49 // Space
        case ".":
            return 47
        case ",":
            return 43
        case "!":
            return 18 // 1 with shift
        case "?":
            return 44 // / with shift
        default:
            // For characters we don't have mapped, use the Unicode input method
            return 49 // Default to space
        }
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