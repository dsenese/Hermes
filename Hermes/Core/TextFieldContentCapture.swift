//
//  TextFieldContentCapture.swift
//  Hermes
//
//  Created by Claude Code on 8/6/25.
//

import Foundation
import AppKit
import ApplicationServices

/// Captures existing text content and cursor state from active text fields for context-aware injection
@MainActor
class TextFieldContentCapture: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var currentContent: TextFieldContent = TextFieldContent()
    @Published private(set) var lastCaptureTime: Date = .distantPast
    
    // MARK: - Private Properties
    
    private var cachedElement: AXUIElement?
    private var cacheTime: Date = .distantPast
    private let cacheTimeout: TimeInterval = 0.5 // 500ms cache
    
    // MARK: - Public Methods
    
    /// Capture current text field content and state
    func captureCurrentContent() async -> TextFieldContent {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            if duration > 0.1 {
                print("⚠️ Content capture took \(Int(duration * 1000))ms")
            }
        }
        
        do {
            let focusedElement = try getFocusedElement()
            let content = try await extractContentFromElement(focusedElement)
            
            // Update published properties
            currentContent = content
            lastCaptureTime = Date()
            
            return content
            
        } catch {
            print("❌ Failed to capture text field content: \(error)")
            let emptyContent = TextFieldContent()
            currentContent = emptyContent
            return emptyContent
        }
    }
    
    /// Get the current content without re-capturing (uses cached value)
    func getCachedContent() -> TextFieldContent {
        return currentContent
    }
    
    /// Check if we need to recapture content (cache is stale)
    var shouldRecapture: Bool {
        return Date().timeIntervalSince(lastCaptureTime) > cacheTimeout
    }
    
    /// Capture content only if cache is stale
    func captureIfNeeded() async -> TextFieldContent {
        if shouldRecapture {
            return await captureCurrentContent()
        } else {
            return currentContent
        }
    }
    
    // MARK: - Private Methods
    
    /// Get the currently focused UI element
    private func getFocusedElement() throws -> AXUIElement {
        // Use cached element if still valid
        let now = Date()
        if now.timeIntervalSince(cacheTime) < cacheTimeout,
           let cached = cachedElement,
           isElementStillValid(cached) {
            return cached
        }
        
        // Get the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            throw ContentCaptureError.noFrontmostApplication
        }
        
        // Get the AX application element
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        // Get the focused element
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else {
            throw ContentCaptureError.noFocusedElement
        }
        
        let axElement = (element as! AXUIElement)
        
        // Cache the element
        cachedElement = axElement
        cacheTime = now
        
        return axElement
    }
    
    /// Check if an AX element is still valid and accessible
    private func isElementStillValid(_ element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        return result == .success
    }
    
    /// Extract comprehensive content information from an AX element
    private func extractContentFromElement(_ element: AXUIElement) async throws -> TextFieldContent {
        var content = TextFieldContent()
        
        // Get element role
        content.elementRole = try getElementRole(element)
        
        // Get text content
        content.text = getElementText(element) ?? ""
        
        // Get selection information
        content.selectionRange = getSelectionRange(element)
        content.hasSelection = content.selectionRange.length > 0
        
        // Get cursor position
        content.cursorPosition = getCursorPosition(element)
        
        // Get element properties
        content.isEditable = isElementEditable(element)
        content.isMultiline = isElementMultiline(element)
        content.placeholder = getPlaceholderText(element) ?? ""
        
        // Get context information
        content.fieldTitle = getFieldTitle(element) ?? ""
        content.fieldDescription = getFieldDescription(element) ?? ""
        
        // Calculate derived properties
        content.isEmpty = content.text.isEmpty
        content.wordCount = content.text.split(separator: " ").count
        content.characterCount = content.text.count
        content.lineCount = content.text.components(separatedBy: .newlines).count
        
        // Get surrounding context (nearby text fields)
        content.surroundingContext = await getSurroundingContext(element)
        
        return content
    }
    
    /// Get the role of an AX element
    private func getElementRole(_ element: AXUIElement) throws -> String {
        var role: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        guard result == .success, let roleString = role as? String else {
            return kAXUnknownRole
        }
        
        return roleString
    }
    
    /// Get text content from an AX element
    private func getElementText(_ element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        guard result == .success else { return nil }
        return value as? String
    }
    
    /// Get the current selection range
    private func getSelectionRange(_ element: AXUIElement) -> NSRange {
        var selectedTextRange: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedTextRange)
        
        guard result == .success,
              let range = selectedTextRange,
              CFGetTypeID(range) == AXValueGetTypeID() else {
            return NSRange(location: 0, length: 0)
        }
        
        var rangeValue: CFRange = CFRangeMake(0, 0)
        if AXValueGetValue(range as! AXValue, .cfRange, &rangeValue) {
            return NSRange(location: rangeValue.location, length: rangeValue.length)
        }
        
        return NSRange(location: 0, length: 0)
    }
    
    /// Get cursor position (insertion point)
    private func getCursorPosition(_ element: AXUIElement) -> Int {
        let selectionRange = getSelectionRange(element)
        return selectionRange.location
    }
    
    /// Check if element is editable
    private func isElementEditable(_ element: AXUIElement) -> Bool {
        let role = (try? getElementRole(element)) ?? ""
        return [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role)
    }
    
    /// Check if element supports multiple lines
    private func isElementMultiline(_ element: AXUIElement) -> Bool {
        let role = (try? getElementRole(element)) ?? ""
        return role == kAXTextAreaRole
    }
    
    /// Get placeholder text if available
    private func getPlaceholderText(_ element: AXUIElement) -> String? {
        var placeholder: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXPlaceholderValueAttribute as CFString, &placeholder)
        
        guard result == .success else { return nil }
        return placeholder as? String
    }
    
    /// Get field title/label
    private func getFieldTitle(_ element: AXUIElement) -> String? {
        var title: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        
        guard result == .success else { return nil }
        return title as? String
    }
    
    /// Get field description
    private func getFieldDescription(_ element: AXUIElement) -> String? {
        var description: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        
        guard result == .success else { return nil }
        return description as? String
    }
    
    /// Get surrounding context (nearby fields, labels, etc.)
    private func getSurroundingContext(_ element: AXUIElement) async -> [String] {
        var context: [String] = []
        
        // Try to get parent container
        var parent: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent) == .success,
           let parentElement = parent {
            
            // Get sibling elements
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(parentElement as! AXUIElement, kAXChildrenAttribute as CFString, &children) == .success,
               let childrenArray = children as? [AXUIElement] {
                
                for child in childrenArray.prefix(5) { // Limit to 5 siblings for performance
                    if let childText = getElementText(child), !childText.isEmpty {
                        context.append(childText.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines))
                    } else if let childTitle = getFieldTitle(child), !childTitle.isEmpty {
                        context.append(childTitle)
                    }
                }
            }
        }
        
        return context
    }
}

// MARK: - Supporting Types

/// Complete information about a text field's current state and content
struct TextFieldContent {
    // Basic content
    var text: String = ""
    var isEmpty: Bool = true
    var characterCount: Int = 0
    var wordCount: Int = 0
    var lineCount: Int = 1
    
    // Selection and cursor
    var selectionRange: NSRange = NSRange(location: 0, length: 0)
    var hasSelection: Bool = false
    var cursorPosition: Int = 0
    
    // Element properties
    var elementRole: String = kAXUnknownRole
    var isEditable: Bool = false
    var isMultiline: Bool = false
    var placeholder: String = ""
    
    // Context information
    var fieldTitle: String = ""
    var fieldDescription: String = ""
    var surroundingContext: [String] = []
    
    // Computed properties
    var selectedText: String {
        guard hasSelection && selectionRange.location + selectionRange.length <= text.count else {
            return ""
        }
        let startIndex = text.index(text.startIndex, offsetBy: selectionRange.location)
        let endIndex = text.index(startIndex, offsetBy: selectionRange.length)
        return String(text[startIndex..<endIndex])
    }
    
    var textBeforeCursor: String {
        guard cursorPosition <= text.count else { return text }
        let endIndex = text.index(text.startIndex, offsetBy: cursorPosition)
        return String(text[..<endIndex])
    }
    
    var textAfterCursor: String {
        guard cursorPosition < text.count else { return "" }
        let startIndex = text.index(text.startIndex, offsetBy: cursorPosition)
        return String(text[startIndex...])
    }
    
    var isAtBeginning: Bool {
        return cursorPosition == 0
    }
    
    var isAtEnd: Bool {
        return cursorPosition >= text.count
    }
    
    var contextDescription: String {
        var parts: [String] = []
        
        if !fieldTitle.isEmpty {
            parts.append("Field: \(fieldTitle)")
        }
        
        if !text.isEmpty {
            parts.append("Content: \(text.prefix(50))\(text.count > 50 ? "..." : "")")
        } else if !placeholder.isEmpty {
            parts.append("Placeholder: \(placeholder)")
        }
        
        if hasSelection {
            parts.append("Selection: \(selectionRange.length) chars")
        } else {
            parts.append("Cursor at: \(cursorPosition)")
        }
        
        return parts.joined(separator: " | ")
    }
}

/// Errors that can occur during content capture
enum ContentCaptureError: LocalizedError {
    case noFrontmostApplication
    case noFocusedElement
    case elementNotAccessible
    case contentExtractionFailed
    
    var errorDescription: String? {
        switch self {
        case .noFrontmostApplication:
            return "No frontmost application found"
        case .noFocusedElement:
            return "No focused text element found"
        case .elementNotAccessible:
            return "Text element is not accessible"
        case .contentExtractionFailed:
            return "Failed to extract content from element"
        }
    }
}