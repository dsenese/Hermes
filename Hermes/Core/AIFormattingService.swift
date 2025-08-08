//
//  AIFormattingService.swift
//  Hermes
//
//  Created by Claude Code on 8/7/25.
//

import Foundation
import Combine

/// Context types for AI formatting based on the target application
enum FormattingContext: String, CaseIterable {
    case casual = "casual"
    case email = "email"
    case code = "code"
    case formal = "formal"
    case messaging = "messaging"
    case document = "document"
    case social = "social"

    var displayName: String {
        switch self {
        case .casual: return "Casual"
        case .email: return "Email"
        case .code: return "Code/Technical"
        case .formal: return "Formal"
        case .messaging: return "Messaging"
        case .document: return "Document"
        case .social: return "Social Media"
        }
    }

    var systemPrompt: String {
        switch self {
        case .casual:
            return "Format this dictated text for casual conversation. Keep it natural and conversational while correcting obvious errors. Maintain the speaker's tone and intent."
        case .email:
            return "Format this dictated text for professional email communication. Ensure proper grammar, punctuation, and business-appropriate tone while preserving the original meaning."
        case .code:
            return "Format this dictated text for technical/code documentation. Use proper technical terminology, correct variable naming conventions, and maintain coding context. Preserve technical accuracy."
        case .formal:
            return "Format this dictated text for formal writing. Use sophisticated vocabulary, proper grammar, and professional tone suitable for official documents or presentations."
        case .messaging:
            return "Format this dictated text for messaging apps. Keep it concise, natural, and conversational. Fix obvious errors but maintain the casual tone."
        case .document:
            return "Format this dictated text for document writing. Ensure proper grammar, punctuation, and structure suitable for reports, articles, or formal content."
        case .social:
            return "Format this dictated text for social media. Keep it engaging, concise, and appropriate for social platforms while correcting errors."
        }
    }
}

/// Configuration for AI formatting behavior
struct AIFormattingConfig {
    var isEnabled: Bool = true
    var aggressiveCorrection: Bool = false
    var preserveStyle: Bool = true
    var contextDetection: Bool = true
    var maxProcessingTime: TimeInterval = 3.0

    static let `default` = AIFormattingConfig()
}

/// Service for AI-powered text formatting and correction using GPT-OSS-20b
@MainActor
class AIFormattingService: ObservableObject {
    // MARK: - Singleton
    static let shared = AIFormattingService()

    // MARK: - Published Properties
    @Published private(set) var isInitialized = false
    @Published private(set) var isProcessing = false
    @Published private(set) var lastProcessingTime: TimeInterval = 0
    @Published var config = AIFormattingConfig.default

    // MARK: - Private Properties
    private let dictionaryManager = CustomDictionaryManager.shared
    private let contentCapture = TextFieldContentCapture()
    private var cancellables = Set<AnyCancellable>()

    // LLM integration (will be implemented once LLM.swift is added)
    // private var llmService: LLMService?

    private init() {
        setupLLMIntegration()
    }

    // MARK: - Public Methods

    /// Initialize the AI formatting service
    func initialize() async throws {
        guard !isInitialized else { return }

        print("🤖 Initializing AI formatting service...")

        // TODO: Initialize GPT-OSS-20b model through LLM.swift
        // This will be implemented once the dependency is added

        isInitialized = true
        print("✅ AI formatting service initialized")
    }

    /// Format text using AI and dictionary corrections, taking into account the current text field content for accurate context across sessions
    func formatText(_ text: String, context: FormattingContext? = nil, appBundleId: String? = nil) async -> String {
        let startTime = Date()

        guard config.isEnabled else {
            // Apply only dictionary corrections if AI formatting is disabled
            return dictionaryManager.applyCorrections(to: text)
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return text
        }

        isProcessing = true
        defer { isProcessing = false }

        print("🤖 Starting AI formatting for text: '\(text.prefix(50))...'")

        // Step 1: Apply dictionary corrections first
        let dictionaryCorrectedText = dictionaryManager.applyCorrections(to: text)
        print("📖 Dictionary corrections applied")

        // Step 2: Capture current text field content for broader context (across sessions)
        let existingContent: TextFieldContent = await contentCapture.captureIfNeeded()
        print("🧩 Existing field context: \(existingContent.contextDescription)")

        // Step 3: Detect context if not provided
        let detectedContext = context ?? (config.contextDetection ? detectContext(appBundleId: appBundleId) : .casual)
        print("🎯 Using formatting context: \(detectedContext.displayName)")

        // Step 4: Apply AI formatting, guided by existing field content
        let aiFormattedText = await applyAIFormatting(dictionaryCorrectedText, context: detectedContext, existingContent: existingContent)

        // Step 5: Re-apply dictionary to enforce exact capitalization/spelling after AI tweaks
        let finalText = dictionaryManager.applyCorrections(to: aiFormattedText)

        let processingTime = Date().timeIntervalSince(startTime)
        lastProcessingTime = processingTime

        print("✅ AI formatting completed in \(String(format: "%.2f", processingTime * 1000))ms")
        print("🤖 Result: '\(finalText)'")

        return finalText
    }

    /// Update formatting configuration
    func updateConfig(_ newConfig: AIFormattingConfig) {
        config = newConfig
        print("🤖 AI formatting config updated")
    }

    // MARK: - Private Methods

    private func setupLLMIntegration() {
        // TODO: Set up LLM.swift integration for GPT-OSS-20b
        // This will be implemented once the dependency is added
        print("🤖 LLM integration setup pending dependency addition")
    }

    private func detectContext(appBundleId: String?) -> FormattingContext {
        guard let bundleId = appBundleId?.lowercased() else {
            return .casual
        }

        // Detect context based on application bundle ID
        if bundleId.contains("mail") || bundleId.contains("outlook") || bundleId.contains("airmail") {
            return .email
        } else if bundleId.contains("xcode") || bundleId.contains("vscode") || bundleId.contains("sublimetext") || bundleId.contains("atom") {
            return .code
        } else if bundleId.contains("messages") || bundleId.contains("whatsapp") || bundleId.contains("telegram") || bundleId.contains("slack") {
            return .messaging
        } else if bundleId.contains("pages") || bundleId.contains("word") || bundleId.contains("docs") || bundleId.contains("notion") {
            return .document
        } else if bundleId.contains("twitter") || bundleId.contains("facebook") || bundleId.contains("instagram") || bundleId.contains("linkedin") {
            return .social
        } else {
            return .casual
        }
    }

    private func applyAIFormatting(_ text: String, context: FormattingContext, existingContent: TextFieldContent?) async -> String {
        // TODO: Implement actual GPT-OSS-20b integration
        // For now, return a placeholder implementation with basic formatting

        // Simulate AI processing delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        return placeholderFormatting(text, context: context, existingContent: existingContent)
    }

    // Placeholder formatting until GPT-OSS-20b is integrated
    private func placeholderFormatting(_ text: String, context: FormattingContext, existingContent: TextFieldContent?) -> String {
        var formatted = text
        let before = existingContent?.textBeforeCursor ?? ""
        let after = existingContent?.textAfterCursor ?? ""
        let isAtSentenceStart = before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                before.hasSuffix(".") || before.hasSuffix("!") || before.hasSuffix("?") ||
                                before.hasSuffix("\n")

        // Basic formatting rules based on context
        switch context {
        case .email, .formal, .document:
            // Ensure sentence starts capitalized only if at sentence start
            if isAtSentenceStart, let first = formatted.first {
                formatted.replaceSubrange(formatted.startIndex...formatted.startIndex, with: String(first).uppercased())
            }

            // Add proper punctuation if it appears to be a complete sentence and not followed by punctuation
            if !formatted.isEmpty,
               !formatted.hasSuffix(".") && !formatted.hasSuffix("!") && !formatted.hasSuffix("?"),
               (after.isEmpty || ![".", "!", "?", ",", ":", ";"].contains(where: { after.hasPrefix($0) })) {
                let wordCount = formatted.split(separator: " ").count
                if wordCount >= 3 { formatted += "." }
            }

        case .code:
            // For code context, maintain technical terminology
            formatted = formatted.replacingOccurrences(of: " dot ", with: ".")
            formatted = formatted.replacingOccurrences(of: " equals ", with: " = ")
            formatted = formatted.replacingOccurrences(of: " open paren ", with: "(")
            formatted = formatted.replacingOccurrences(of: " close paren ", with: ")")

        case .messaging, .social, .casual:
            // Keep casual tone, minimal changes
            break
        }

        return formatted.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Extensions

extension AIFormattingService {
    /// Get performance statistics
    var performanceStats: AIFormattingStats {
        AIFormattingStats(
            isInitialized: isInitialized,
            lastProcessingTime: lastProcessingTime,
            averageProcessingTime: lastProcessingTime, // TODO: Calculate actual average
            successfulFormatting: 0 // TODO: Track successful formatting count
        )
    }
}

/// Statistics about AI formatting performance
struct AIFormattingStats {
    let isInitialized: Bool
    let lastProcessingTime: TimeInterval
    let averageProcessingTime: TimeInterval
    let successfulFormatting: Int
}

// MARK: - Context Detection Helpers

extension AIFormattingService {
    /// Common application bundle ID patterns for context detection
    static let contextPatterns: [FormattingContext: [String]] = [
        .email: ["mail", "outlook", "airmail", "spark", "canary"],
        .code: ["xcode", "vscode", "sublimetext", "atom", "nova", "coderunner"],
        .messaging: ["messages", "whatsapp", "telegram", "slack", "discord", "teams"],
        .document: ["pages", "word", "docs", "notion", "bear", "obsidian"],
        .social: ["twitter", "facebook", "instagram", "linkedin", "mastodon", "threads"]
    ]

    /// Get suggested context for an application
    static func getSuggestedContext(for bundleId: String) -> FormattingContext {
        let lowercasedId = bundleId.lowercased()

        for (context, patterns) in contextPatterns {
            if patterns.contains(where: { lowercasedId.contains($0) }) {
                return context
            }
        }

        return .casual
    }
}
