//
//  DictationHistoryManager.swift
//  Hermes
//
//  Created by Claude Code on 7/29/25.
//

import Foundation
import SwiftUI

/// Manages dictation history with privacy controls and local storage
@MainActor
class DictationHistoryManager: ObservableObject {
    static let shared = DictationHistoryManager()
    
    @Published private(set) var recentSessions: [DictationSession] = []
    @Published private(set) var totalSessions: Int = 0
    @Published private(set) var totalCharacters: Int = 0
    
    private let fileManager = FileManager.default
    private let historyDirectory: URL
    
    private init() {
        // Create history directory in Application Support
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        historyDirectory = appSupport.appendingPathComponent("Hermes/History")
        
        createHistoryDirectoryIfNeeded()
        loadRecentSessions()
    }
    
    // MARK: - Public Methods
    
    func recordSession(_ session: DictationSession) {
        let settings = UserSettings.shared
        
        // Check privacy settings
        guard settings.privacySettings.storeDictationHistory else {
            print("🔒 History storage disabled by privacy settings")
            return
        }
        
        // Update in-memory data
        recentSessions.insert(session, at: 0)
        if recentSessions.count > 100 { // Keep only recent 100 sessions in memory
            recentSessions.removeLast()
        }
        
        totalSessions += 1
        totalCharacters += session.transcribedText.count
        
        // Save to disk if not in privacy mode
        if !settings.privacySettings.isPrivacyModeEnabled {
            saveSessionToDisk(session)
        }
        
        // Auto-cleanup if configured
        if let deleteAfterDays = settings.privacySettings.autoDeleteHistoryAfterDays {
            cleanupOldSessions(olderThanDays: deleteAfterDays)
        }
    }
    
    func getSessions(limit: Int = 50, offset: Int = 0) -> [DictationSession] {
        let endIndex = min(offset + limit, recentSessions.count)
        guard offset < recentSessions.count else { return [] }
        
        return Array(recentSessions[offset..<endIndex])
    }
    
    func searchSessions(query: String) -> [DictationSession] {
        guard !query.isEmpty else { return recentSessions }
        
        return recentSessions.filter { session in
            session.transcribedText.localizedCaseInsensitiveContains(query) ||
            session.applicationName?.localizedCaseInsensitiveContains(query) ?? false
        }
    }
    
    func deleteSession(_ session: DictationSession) {
        recentSessions.removeAll { $0.id == session.id }
        deleteSessionFromDisk(session)
        
        totalSessions = max(0, totalSessions - 1)
        totalCharacters = max(0, totalCharacters - session.transcribedText.count)
    }
    
    func clearAllHistory() {
        recentSessions.removeAll()
        totalSessions = 0
        totalCharacters = 0
        
        // Delete all files from disk
        clearHistoryDirectory()
    }
    
    func exportHistory(format: ExportFormat) -> Data? {
        switch format {
        case .json:
            return exportAsJSON()
        case .csv:
            return exportAsCSV()
        case .txt:
            return exportAsText()
        }
    }
    
    // MARK: - Analytics and Insights
    
    func getUsageStats(for period: StatsPeriod) -> UsageStats {
        let calendar = Calendar.current
        let now = Date()
        
        let sessions = recentSessions.filter { session in
            switch period {
            case .today:
                return calendar.isDate(session.timestamp, inSameDayAs: now)
            case .thisWeek:
                return calendar.dateInterval(of: .weekOfYear, for: now)?.contains(session.timestamp) ?? false
            case .thisMonth:
                return calendar.dateInterval(of: .month, for: now)?.contains(session.timestamp) ?? false
            case .allTime:
                return true
            }
        }
        
        let totalCharacters = sessions.reduce(0) { $0 + $1.transcribedText.count }
        let totalDuration = sessions.reduce(0) { $0 + $1.duration }
        let averageAccuracy = sessions.compactMap { $0.accuracy }.reduce(0, +) / Double(max(1, sessions.count))
        
        return UsageStats(
            sessionCount: sessions.count,
            totalCharacters: totalCharacters,
            totalDuration: totalDuration,
            averageAccuracy: averageAccuracy,
            mostUsedApps: getMostUsedApps(from: sessions),
            peakUsageHours: getPeakUsageHours(from: sessions)
        )
    }
    
    // MARK: - Private Methods
    
    private func createHistoryDirectoryIfNeeded() {
        do {
            try fileManager.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create history directory: \(error)")
        }
    }
    
    private func loadRecentSessions() {
        do {
            let files = try fileManager.contentsOfDirectory(at: historyDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            let sessionFiles = files
                .filter { $0.pathExtension == "json" }
                .sorted { file1, file2 in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }
                .prefix(100) // Load only recent 100 sessions
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            for file in sessionFiles {
                do {
                    let data = try Data(contentsOf: file)
                    let session = try decoder.decode(DictationSession.self, from: data)
                    recentSessions.append(session)
                } catch {
                    print("⚠️ Failed to load session from \(file.lastPathComponent): \(error)")
                }
            }
            
            print("✅ Loaded \(recentSessions.count) sessions from history")
            
        } catch {
            print("⚠️ Failed to load history directory: \(error)")
        }
    }
    
    private func saveSessionToDisk(_ session: DictationSession) {
        let filename = "\(session.id.uuidString).json"
        let fileURL = historyDirectory.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(session)
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to save session to disk: \(error)")
        }
    }
    
    private func deleteSessionFromDisk(_ session: DictationSession) {
        let filename = "\(session.id.uuidString).json"
        let fileURL = historyDirectory.appendingPathComponent(filename)
        
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            print("⚠️ Failed to delete session file: \(error)")
        }
    }
    
    private func clearHistoryDirectory() {
        do {
            let files = try fileManager.contentsOfDirectory(at: historyDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
            print("✅ Cleared all history files")
        } catch {
            print("❌ Failed to clear history directory: \(error)")
        }
    }
    
    private func cleanupOldSessions(olderThanDays days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        recentSessions.removeAll { $0.timestamp < cutoffDate }
        
        // Also delete from disk
        do {
            let files = try fileManager.contentsOfDirectory(at: historyDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for file in files {
                let resourceValues = try file.resourceValues(forKeys: [.creationDateKey])
                if let creationDate = resourceValues.creationDate, creationDate < cutoffDate {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("⚠️ Failed to cleanup old sessions: \(error)")
        }
    }
    
    // MARK: - Export Methods
    
    private func exportAsJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            return try encoder.encode(recentSessions)
        } catch {
            print("❌ Failed to export as JSON: \(error)")
            return nil
        }
    }
    
    private func exportAsCSV() -> Data? {
        var csv = "Timestamp,Duration,Text,Application,Accuracy,Language\n"
        
        for session in recentSessions {
            let timestamp = ISO8601DateFormatter().string(from: session.timestamp)
            let duration = String(format: "%.2f", session.duration)
            let text = session.transcribedText.replacingOccurrences(of: "\"", with: "\"\"")
            let app = session.applicationName ?? ""
            let accuracy = session.accuracy.map { String(format: "%.2f", $0) } ?? ""
            let language = session.language ?? ""
            
            csv += "\"\(timestamp)\",\"\(duration)\",\"\(text)\",\"\(app)\",\"\(accuracy)\",\"\(language)\"\n"
        }
        
        return csv.data(using: .utf8)
    }
    
    private func exportAsText() -> Data? {
        var text = "Hermes Dictation History\n"
        text += "========================\n\n"
        
        for session in recentSessions {
            text += "Date: \(DateFormatter.localizedString(from: session.timestamp, dateStyle: .medium, timeStyle: .short))\n"
            text += "Duration: \(String(format: "%.2f", session.duration))s\n"
            if let app = session.applicationName {
                text += "Application: \(app)\n"
            }
            text += "Transcribed Text:\n\(session.transcribedText)\n"
            text += "\n---\n\n"
        }
        
        return text.data(using: .utf8)
    }
    
    // MARK: - Analytics Helpers
    
    private func getMostUsedApps(from sessions: [DictationSession]) -> [AppUsage] {
        let appCounts = Dictionary(grouping: sessions.compactMap { $0.applicationName }) { $0 }
            .mapValues { $0.count }
        
        return appCounts.map { AppUsage(appName: $0.key, sessionCount: $0.value) }
            .sorted { $0.sessionCount > $1.sessionCount }
            .prefix(5)
            .map { $0 }
    }
    
    private func getPeakUsageHours(from sessions: [DictationSession]) -> [HourlyUsage] {
        let calendar = Calendar.current
        let hourCounts = Dictionary(grouping: sessions) { session in
            calendar.component(.hour, from: session.timestamp)
        }.mapValues { $0.count }
        
        return (0...23).map { hour in
            HourlyUsage(hour: hour, sessionCount: hourCounts[hour] ?? 0)
        }
    }
}

// MARK: - Supporting Types

struct DictationSession: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
    let transcribedText: String
    let applicationName: String?
    let accuracy: Double?
    let language: String?
    let modelUsed: String?
    let characterCount: Int
    
    init(
        transcribedText: String,
        applicationName: String? = nil,
        duration: TimeInterval,
        accuracy: Double? = nil,
        language: String? = nil,
        modelUsed: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.duration = duration
        self.transcribedText = transcribedText
        self.applicationName = applicationName
        self.accuracy = accuracy
        self.language = language
        self.modelUsed = modelUsed
        self.characterCount = transcribedText.count
    }
}

struct UsageStats {
    let sessionCount: Int
    let totalCharacters: Int
    let totalDuration: TimeInterval
    let averageAccuracy: Double
    let mostUsedApps: [AppUsage]
    let peakUsageHours: [HourlyUsage]
}

struct AppUsage {
    let appName: String
    let sessionCount: Int
}

struct HourlyUsage {
    let hour: Int
    let sessionCount: Int
}

enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
    case txt = "Text"
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .txt: return "txt"
        }
    }
}

enum StatsPeriod: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case allTime = "All Time"
}