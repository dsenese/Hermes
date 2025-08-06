//
//  DictationSessionManager.swift
//  Hermes
//
//  Created by Claude Code on 8/6/25.
//

import Foundation
import AppKit

/// Manages dictation sessions for batch additions and context continuity
@MainActor
class DictationSessionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var currentSession: EnhancedDictationSession?
    @Published private(set) var sessionHistory: [EnhancedDictationSession] = []
    @Published private(set) var totalSessionsToday: Int = 0
    
    // MARK: - Private Properties
    
    private let maxSessionHistory = 10
    private let sessionTimeout: TimeInterval = 300 // 5 minutes
    private var sessionTimer: Timer?
    
    // Persistence
    private let sessionStorageKey = "HermesDictationSessions"
    private let dailyCountKey = "HermesDailySessionCount"
    private let lastSessionDateKey = "HermesLastSessionDate"
    
    // MARK: - Initialization
    
    init() {
        loadStoredSessions()
        updateDailyCount()
    }
    
    deinit {
        sessionTimer?.invalidate()
    }
    
    // MARK: - Session Management
    
    /// Start a new dictation session
    func startSession(context: ContextInfo, initialContent: TextFieldContent) -> String {
        // End any existing session first
        if let existing = currentSession {
            endSession(sessionId: existing.id, reason: .newSessionStarted)
        }
        
        let session = EnhancedDictationSession(
            context: context,
            initialContent: initialContent
        )
        
        currentSession = session
        
        // Set up session timeout
        startSessionTimer()
        
        // Update statistics
        totalSessionsToday += 1
        
        print("🎤 Started dictation session: \(session.id) in \(context.applicationName)")
        
        return session.id
    }
    
    /// Add text to the current session
    func addToSession(sessionId: String, text: String, formattedText: String? = nil) -> Bool {
        guard let session = currentSession, session.id == sessionId else {
            print("⚠️ Cannot add to session \(sessionId) - not current or not found")
            return false
        }
        
        let entry = DictationEntry(
            originalText: text,
            formattedText: formattedText ?? text,
            timestamp: Date()
        )
        
        session.entries.append(entry)
        session.lastUpdateTime = Date()
        session.totalCharacters += text.count
        session.totalWords += text.split(separator: " ").count
        
        // Reset session timer
        startSessionTimer()
        
        print("📝 Added to session \(sessionId): '\(text.prefix(30))...' (\(session.entries.count) entries)")
        
        return true
    }
    
    /// Update session context (e.g., user switched fields)
    func updateSessionContext(sessionId: String, newContext: ContextInfo, newContent: TextFieldContent) -> Bool {
        guard let session = currentSession, session.id == sessionId else {
            return false
        }
        
        // Only update if we're still in the same app
        if newContext.bundleID == session.context.bundleID {
            session.context = newContext
            session.lastUpdateTime = Date()
            
            print("🔄 Updated session context: \(newContext.description)")
            return true
        } else {
            // Different app - end current session
            endSession(sessionId: sessionId, reason: .contextChanged)
            return false
        }
    }
    
    /// End the current session
    func endSession(sessionId: String, reason: SessionEndReason = .userInitiated) {
        guard let session = currentSession, session.id == sessionId else {
            return
        }
        
        session.endTime = Date()
        session.endReason = reason
        session.isActive = false
        
        // Calculate final statistics
        if let startTime = session.startTime, let endTime = session.endTime {
            session.duration = endTime.timeIntervalSince(startTime)
        }
        
        // Add to history
        sessionHistory.insert(session, at: 0)
        if sessionHistory.count > maxSessionHistory {
            sessionHistory.removeLast()
        }
        
        // Clear current session
        currentSession = nil
        
        // Stop timer
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // Save to storage
        saveSessionHistory()
        
        print("🏁 Ended session \(sessionId): \(session.entries.count) entries, \(session.totalCharacters) chars, reason: \(reason)")
    }
    
    /// Get the current session if active
    func getCurrentSession() -> EnhancedDictationSession? {
        return currentSession
    }
    
    /// Get combined text from current session
    func getCurrentSessionText() -> String {
        guard let session = currentSession else { return "" }
        return session.entries.map { $0.formattedText }.joined(separator: " ")
    }
    
    /// Check if there's an active session
    var hasActiveSession: Bool {
        return currentSession?.isActive ?? false
    }
    
    /// Get session statistics for today
    func getTodayStatistics() -> SessionStatistics {
        let today = Calendar.current.startOfDay(for: Date())
        let todaySessions = sessionHistory.filter { session in
            guard let startTime = session.startTime else { return false }
            return Calendar.current.startOfDay(for: startTime) == today
        }
        
        let totalEntries = todaySessions.reduce(0) { $0 + $1.entries.count }
        let totalCharacters = todaySessions.reduce(0) { $0 + $1.totalCharacters }
        let totalWords = todaySessions.reduce(0) { $0 + $1.totalWords }
        let totalDuration = todaySessions.reduce(0) { $0 + ($1.duration ?? 0) }
        
        return SessionStatistics(
            sessionCount: todaySessions.count,
            totalEntries: totalEntries,
            totalCharacters: totalCharacters,
            totalWords: totalWords,
            totalDuration: totalDuration,
            averageSessionDuration: todaySessions.isEmpty ? 0 : totalDuration / Double(todaySessions.count),
            averageWordsPerSession: todaySessions.isEmpty ? 0 : Double(totalWords) / Double(todaySessions.count)
        )
    }
    
    // MARK: - Private Methods
    
    /// Start or restart the session timeout timer
    private func startSessionTimer() {
        sessionTimer?.invalidate()
        
        sessionTimer = Timer.scheduledTimer(withTimeInterval: sessionTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let session = self.currentSession else { return }
                self.endSession(sessionId: session.id, reason: .timeout)
            }
        }
    }
    
    /// Load stored session history (simplified - just load count for now)
    private func loadStoredSessions() {
        // For now, we'll just track basic statistics without full persistence
        // This can be enhanced later with a proper Codable session model
        sessionHistory = []
    }
    
    /// Save session history to storage (simplified)
    private func saveSessionHistory() {
        // For now, we'll just save basic statistics
        // Full session persistence can be added later
    }
    
    /// Update the daily session count
    private func updateDailyCount() {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastDate = UserDefaults.standard.object(forKey: lastSessionDateKey) as? Date,
           Calendar.current.startOfDay(for: lastDate) == today {
            // Same day - load existing count
            totalSessionsToday = UserDefaults.standard.integer(forKey: dailyCountKey)
        } else {
            // New day - reset count
            totalSessionsToday = 0
            UserDefaults.standard.set(0, forKey: dailyCountKey)
            UserDefaults.standard.set(Date(), forKey: lastSessionDateKey)
        }
    }
    
    /// Save daily count
    private func saveDailyCount() {
        UserDefaults.standard.set(totalSessionsToday, forKey: dailyCountKey)
        UserDefaults.standard.set(Date(), forKey: lastSessionDateKey)
    }
}

// MARK: - Supporting Types

/// Represents a dictation session with context and entries
class EnhancedDictationSession: ObservableObject {
    let id: String
    var context: ContextInfo
    let initialContent: TextFieldContent
    var entries: [DictationEntry] = []
    let startTime: Date?
    var endTime: Date?
    var lastUpdateTime: Date
    var duration: TimeInterval?
    var endReason: SessionEndReason?
    var isActive: Bool = true
    
    // Statistics
    var totalCharacters: Int = 0
    var totalWords: Int = 0
    
    init(context: ContextInfo, initialContent: TextFieldContent) {
        self.id = UUID().uuidString
        self.context = context
        self.initialContent = initialContent
        self.startTime = Date()
        self.lastUpdateTime = Date()
    }
    
    // Computed properties
    var entryCount: Int { entries.count }
    var combinedText: String { entries.map { $0.formattedText }.joined(separator: " ") }
    var averageEntryLength: Double {
        guard !entries.isEmpty else { return 0 }
        return Double(totalCharacters) / Double(entries.count)
    }
}

/// Individual dictation entry within a session
struct DictationEntry: Codable {
    let id: String
    let originalText: String
    let formattedText: String
    let timestamp: Date
    let characterCount: Int
    let wordCount: Int
    
    init(originalText: String, formattedText: String, timestamp: Date) {
        self.id = UUID().uuidString
        self.originalText = originalText
        self.formattedText = formattedText
        self.timestamp = timestamp
        self.characterCount = formattedText.count
        self.wordCount = formattedText.split(separator: " ").count
    }
}

/// Reasons why a session ended
enum SessionEndReason: String, Codable, CaseIterable {
    case userInitiated = "User Initiated"
    case timeout = "Timeout"
    case contextChanged = "Context Changed"
    case newSessionStarted = "New Session Started"
    case applicationClosed = "Application Closed"
    case error = "Error"
}

/// Session statistics for analytics
struct SessionStatistics {
    let sessionCount: Int
    let totalEntries: Int
    let totalCharacters: Int
    let totalWords: Int
    let totalDuration: TimeInterval
    let averageSessionDuration: TimeInterval
    let averageWordsPerSession: Double
    
    var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return "\(minutes)m \(seconds)s"
    }
    
    var formattedAverageSession: String {
        let minutes = Int(averageSessionDuration) / 60
        let seconds = Int(averageSessionDuration) % 60
        return "\(minutes)m \(seconds)s"
    }
}