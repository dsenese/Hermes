//
//  ContextAwareTextFormatter.swift
//  Hermes
//
//  Created by Claude Code on 8/6/25.
//

import Foundation

/// Intelligent text formatting based on application context and existing content
@MainActor
class ContextAwareTextFormatter: ObservableObject {
    
    // MARK: - Configuration
    
    private let emailFormatter = EmailTextFormatter()
    private let codeFormatter = CodeTextFormatter()
    private let documentFormatter = DocumentTextFormatter()
    private let chatFormatter = ChatTextFormatter()
    private let defaultFormatter = DefaultTextFormatter()
    
    // MARK: - Public Methods
    
    /// Format text based on application context and existing content
    func formatText(_ text: String, context: ContextInfo, existingContent: TextFieldContent) -> FormattedTextResult {
        // Choose appropriate formatter based on context
        let formatter = getFormatter(for: context)
        
        // Create formatting context
        let formattingContext = TextFormattingContext(
            originalText: text,
            applicationContext: context,
            existingContent: existingContent,
            cursorPosition: existingContent.cursorPosition,
            hasSelection: existingContent.hasSelection,
            isAtBeginning: existingContent.isAtBeginning,
            isAtEnd: existingContent.isAtEnd
        )
        
        // Apply formatting
        let result = formatter.format(text: text, context: formattingContext)
        
        print("📝 Formatted text: '\(text.prefix(30))...' → '\(result.formattedText.prefix(30))...' (\(formatter.name))")
        
        return result
    }
    
    /// Get preview of how text would be formatted
    func previewFormatting(_ text: String, context: ContextInfo, existingContent: TextFieldContent) -> FormattedTextResult {
        // Same as formatText but doesn't log
        let formatter = getFormatter(for: context)
        let formattingContext = TextFormattingContext(
            originalText: text,
            applicationContext: context,
            existingContent: existingContent,
            cursorPosition: existingContent.cursorPosition,
            hasSelection: existingContent.hasSelection,
            isAtBeginning: existingContent.isAtBeginning,
            isAtEnd: existingContent.isAtEnd
        )
        
        return formatter.format(text: text, context: formattingContext)
    }
    
    // MARK: - Private Methods
    
    /// Select appropriate formatter based on context
    private func getFormatter(for context: ContextInfo) -> TextFormatter {
        switch context.applicationType {
        case .email:
            return emailFormatter
        case .codeEditor, .terminal:
            return codeFormatter
        case .document:
            return documentFormatter
        case .chat, .social:
            return chatFormatter
        default:
            return defaultFormatter
        }
    }
}

// MARK: - Text Formatters

/// Base protocol for text formatters
protocol TextFormatter {
    var name: String { get }
    func format(text: String, context: TextFormattingContext) -> FormattedTextResult
}

/// Email-specific text formatting
class EmailTextFormatter: TextFormatter {
    let name = "Email"
    
    func format(text: String, context: TextFormattingContext) -> FormattedTextResult {
        var formattedText = text
        var appliedFormatting: [String] = []
        
        // Email-specific formatting rules
        
        // 1. Capitalize first letter if at beginning of field or after period
        if context.isAtBeginning || context.existingContent.textBeforeCursor.hasSuffix(". ") {
            formattedText = capitalizeFirstLetter(formattedText)
            if formattedText != text {
                appliedFormatting.append("Capitalized first letter")
            }
        }
        
        // 2. Add proper punctuation
        formattedText = addProperPunctuation(formattedText)
        if formattedText != text && !appliedFormatting.contains("Capitalized first letter") {
            appliedFormatting.append("Added punctuation")
        }
        
        // 3. Format common email phrases
        formattedText = formatEmailPhrases(formattedText)
        
        // 4. Handle email signatures
        if context.existingContent.fieldTitle.lowercased().contains("body") && context.isAtEnd {
            formattedText = handleEmailSignature(formattedText, context: context)
        }
        
        // 5. Format greetings and closings
        formattedText = formatGreetingsAndClosings(formattedText, context: context)
        
        return FormattedTextResult(
            formattedText: formattedText,
            originalText: text,
            appliedFormatting: appliedFormatting,
            formatterUsed: name
        )
    }
    
    private func capitalizeFirstLetter(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return text.prefix(1).uppercased() + text.dropFirst()
    }
    
    private func addProperPunctuation(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add period if it's a complete sentence without punctuation
        if result.count > 10 && ![".", "!", "?", ",", ":"].contains(where: { result.hasSuffix($0) }) {
            result += "."
        }
        
        return result
    }
    
    private func formatEmailPhrases(_ text: String) -> String {
        let emailPhrases: [String: String] = [
            "thank you": "Thank you",
            "best regards": "Best regards",
            "kind regards": "Kind regards",
            "sincerely": "Sincerely",
            "looking forward": "Looking forward"
        ]
        
        var result = text
        for (phrase, formatted) in emailPhrases {
            result = result.replacingOccurrences(of: phrase, with: formatted, options: .caseInsensitive)
        }
        
        return result
    }
    
    private func handleEmailSignature(_ text: String, context: TextFormattingContext) -> String {
        // If adding text at the end of email body, ensure proper spacing before signature
        if !text.isEmpty && !context.existingContent.text.hasSuffix("\n\n") {
            return "\n\n" + text
        }
        return text
    }
    
    private func formatGreetingsAndClosings(_ text: String, context: TextFormattingContext) -> String {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Common greetings
        if lowercased.hasPrefix("hello") || lowercased.hasPrefix("hi ") || lowercased.hasPrefix("hey") {
            return capitalizeFirstLetter(text) + (text.hasSuffix(",") ? "" : ",")
        }
        
        // Common closings
        if lowercased.hasPrefix("thanks") || lowercased.hasPrefix("thank you") {
            return capitalizeFirstLetter(text) + (text.hasSuffix(",") || text.hasSuffix(".") ? "" : ".")
        }
        
        return text
    }
}

/// Code-specific text formatting
class CodeTextFormatter: TextFormatter {
    let name = "Code"
    
    func format(text: String, context: TextFormattingContext) -> FormattedTextResult {
        var formattedText = text
        var appliedFormatting: [String] = []
        
        // Code-specific formatting rules
        
        // 1. Preserve exact spacing and indentation
        // (No automatic formatting that might break code)
        
        // 2. Handle common code patterns
        formattedText = formatCodePatterns(formattedText)
        
        // 3. Handle comments
        if text.trimmingCharacters(in: .whitespaces).hasPrefix("//") || 
           text.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            // Ensure space after comment markers
            formattedText = formatComments(formattedText)
            if formattedText != text {
                appliedFormatting.append("Formatted comment")
            }
        }
        
        return FormattedTextResult(
            formattedText: formattedText,
            originalText: text,
            appliedFormatting: appliedFormatting,
            formatterUsed: name
        )
    }
    
    private func formatCodePatterns(_ text: String) -> String {
        // Minimal formatting to avoid breaking code
        return text
    }
    
    private func formatComments(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        if trimmed.hasPrefix("//") && !trimmed.hasPrefix("// ") {
            return text.replacingOccurrences(of: "//", with: "// ")
        }
        
        if trimmed.hasPrefix("#") && !trimmed.hasPrefix("# ") && trimmed != "#" {
            return text.replacingOccurrences(of: "#", with: "# ")
        }
        
        return text
    }
}

/// Document-specific text formatting
class DocumentTextFormatter: TextFormatter {
    let name = "Document"
    
    func format(text: String, context: TextFormattingContext) -> FormattedTextResult {
        var formattedText = text
        var appliedFormatting: [String] = []
        
        // Document-specific formatting
        
        // 1. Proper sentence capitalization
        if context.isAtBeginning || needsCapitalization(context: context) {
            formattedText = capitalizeFirstLetter(formattedText)
            if formattedText != text {
                appliedFormatting.append("Capitalized first letter")
            }
        }
        
        // 2. Smart punctuation
        formattedText = addSmartPunctuation(formattedText, context: context)
        
        // 3. Format common phrases
        formattedText = formatCommonPhrases(formattedText)
        
        // 4. Handle paragraph breaks
        if context.existingContent.isMultiline {
            formattedText = handleParagraphFormatting(formattedText, context: context)
        }
        
        return FormattedTextResult(
            formattedText: formattedText,
            originalText: text,
            appliedFormatting: appliedFormatting,
            formatterUsed: name
        )
    }
    
    private func capitalizeFirstLetter(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return text.prefix(1).uppercased() + text.dropFirst()
    }
    
    private func needsCapitalization(context: TextFormattingContext) -> Bool {
        let beforeText = context.existingContent.textBeforeCursor.trimmingCharacters(in: .whitespaces)
        return beforeText.isEmpty || beforeText.hasSuffix(".") || beforeText.hasSuffix("!") || beforeText.hasSuffix("?")
    }
    
    private func addSmartPunctuation(_ text: String, context: TextFormattingContext) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add period for complete sentences
        if result.count > 15 && ![".", "!", "?", ",", ":", ";"].contains(where: { result.hasSuffix($0) }) {
            // Check if it looks like a complete sentence
            let words = result.split(separator: " ")
            if words.count >= 3 {
                result += "."
            }
        }
        
        return result
    }
    
    private func formatCommonPhrases(_ text: String) -> String {
        let commonCorrections: [String: String] = [
            " i ": " I ",
            " im ": " I'm ",
            " dont ": " don't ",
            " wont ": " won't ",
            " cant ": " can't "
        ]
        
        var result = text
        for (incorrect, correct) in commonCorrections {
            result = result.replacingOccurrences(of: incorrect, with: correct, options: .caseInsensitive)
        }
        
        return result
    }
    
    private func handleParagraphFormatting(_ text: String, context: TextFormattingContext) -> String {
        // Add appropriate line breaks for new paragraphs
        if context.existingContent.textBeforeCursor.hasSuffix(".") && !text.hasPrefix(" ") {
            return "\n\n" + text
        }
        
        return text
    }
}

/// Chat-specific text formatting
class ChatTextFormatter: TextFormatter {
    let name = "Chat"
    
    func format(text: String, context: TextFormattingContext) -> FormattedTextResult {
        var formattedText = text
        var appliedFormatting: [String] = []
        
        // Chat-specific formatting (more casual)
        
        // 1. Minimal capitalization (preserve casual tone)
        if context.isAtBeginning && text.count > 20 {
            // Only capitalize longer messages
            formattedText = capitalizeFirstLetter(formattedText)
            if formattedText != text {
                appliedFormatting.append("Capitalized first letter")
            }
        }
        
        // 2. Handle common abbreviations
        formattedText = expandCommonAbbreviations(formattedText)
        
        // 3. Preserve emojis and casual punctuation
        // (No automatic punctuation addition)
        
        return FormattedTextResult(
            formattedText: formattedText,
            originalText: text,
            appliedFormatting: appliedFormatting,
            formatterUsed: name
        )
    }
    
    private func capitalizeFirstLetter(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return text.prefix(1).uppercased() + text.dropFirst()
    }
    
    private func expandCommonAbbreviations(_ text: String) -> String {
        let abbreviations: [String: String] = [
            " u ": " you ",
            " ur ": " your ",
            " r ": " are "
        ]
        
        var result = text
        for (abbrev, expanded) in abbreviations {
            result = result.replacingOccurrences(of: abbrev, with: expanded, options: .caseInsensitive)
        }
        
        return result
    }
}

/// Default text formatting for unknown contexts
class DefaultTextFormatter: TextFormatter {
    let name = "Default"
    
    func format(text: String, context: TextFormattingContext) -> FormattedTextResult {
        var formattedText = text
        var appliedFormatting: [String] = []
        
        // Basic formatting
        
        // 1. Capitalize if at beginning
        if context.isAtBeginning {
            formattedText = capitalizeFirstLetter(formattedText)
            if formattedText != text {
                appliedFormatting.append("Capitalized first letter")
            }
        }
        
        // 2. Basic punctuation
        formattedText = addBasicPunctuation(formattedText)
        if formattedText != text && appliedFormatting.isEmpty {
            appliedFormatting.append("Added punctuation")
        }
        
        return FormattedTextResult(
            formattedText: formattedText,
            originalText: text,
            appliedFormatting: appliedFormatting,
            formatterUsed: name
        )
    }
    
    private func capitalizeFirstLetter(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        return text.prefix(1).uppercased() + text.dropFirst()
    }
    
    private func addBasicPunctuation(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add period if it looks like a complete sentence
        if trimmed.count > 10 && ![".", "!", "?", ",", ":"].contains(where: { trimmed.hasSuffix($0) }) {
            return trimmed + "."
        }
        
        return trimmed
    }
}

// MARK: - Supporting Types

/// Context information for text formatting
struct TextFormattingContext {
    let originalText: String
    let applicationContext: ContextInfo
    let existingContent: TextFieldContent
    let cursorPosition: Int
    let hasSelection: Bool
    let isAtBeginning: Bool
    let isAtEnd: Bool
}

/// Result of text formatting operation
struct FormattedTextResult {
    let formattedText: String
    let originalText: String
    let appliedFormatting: [String]
    let formatterUsed: String
    
    var wasModified: Bool {
        return formattedText != originalText
    }
    
    var formattingDescription: String {
        if appliedFormatting.isEmpty {
            return "No formatting applied"
        } else {
            return "Applied: \(appliedFormatting.joined(separator: ", "))"
        }
    }
}