//
//  UserSettings.swift
//  Hermes
//
//  Created by Claude Code on 7/29/25.
//

import Foundation
import SwiftUI

// MARK: - Main User Settings Schema

/// Comprehensive user settings that will be stored locally and optionally synced to Supabase
@MainActor
class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    // MARK: - Published Properties
    
    @Published var onboardingSettings: OnboardingSettings
    @Published var keyboardShortcuts: KeyboardShortcuts
    @Published var privacySettings: PrivacySettings
    @Published var dictationSettings: DictationSettings
    @Published var interfaceSettings: InterfaceSettings
    @Published var teamSettings: TeamSettings?
    
    // MARK: - System Properties
    
    @Published var isOnboardingCompleted: Bool
    @Published var lastSyncDate: Date?
    @Published var deviceId: String
    @Published var appVersion: String
    
    private init() {
        // Initialize with default values
        self.onboardingSettings = OnboardingSettings()
        self.keyboardShortcuts = KeyboardShortcuts()
        self.privacySettings = PrivacySettings()
        self.dictationSettings = DictationSettings()
        self.interfaceSettings = InterfaceSettings()
        self.teamSettings = nil
        
        // System properties
        self.isOnboardingCompleted = false
        self.lastSyncDate = nil
        self.deviceId = UserSettings.generateDeviceId()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        // Load from local storage
        loadFromLocalStorage()
    }
    
    // MARK: - Storage Methods
    
    func saveToLocalStorage() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(self.toStorableSettings())
            UserDefaults.standard.set(data, forKey: "HermesUserSettings")
            print("✅ Settings saved locally")
        } catch {
            print("❌ Failed to save settings: \(error)")
        }
    }
    
    private func loadFromLocalStorage() {
        guard let data = UserDefaults.standard.data(forKey: "HermesUserSettings") else {
            print("ℹ️ No local settings found, using defaults")
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let storableSettings = try decoder.decode(StorableUserSettings.self, from: data)
            self.applyStorableSettings(storableSettings)
            print("✅ Settings loaded from local storage")
        } catch {
            print("❌ Failed to load settings: \(error)")
        }
    }
    
    // MARK: - Supabase Sync Methods (Future Implementation)
    
    func syncToSupabase() async {
        guard !privacySettings.isPrivacyModeEnabled else {
            print("🔒 Privacy mode enabled, skipping Supabase sync")
            return
        }
        
        // TODO: Implement Supabase sync
        print("🔄 Supabase sync not yet implemented")
    }
    
    func syncFromSupabase() async {
        // TODO: Implement Supabase sync
        print("🔄 Supabase sync not yet implemented")
    }
    
    // MARK: - Helper Methods
    
    private static func generateDeviceId() -> String {
        if let existingId = UserDefaults.standard.string(forKey: "HermesDeviceId") {
            return existingId
        }
        
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "HermesDeviceId")
        return newId
    }
    
    func resetToDefaults() {
        onboardingSettings = OnboardingSettings()
        keyboardShortcuts = KeyboardShortcuts()
        privacySettings = PrivacySettings()
        dictationSettings = DictationSettings()
        interfaceSettings = InterfaceSettings()
        teamSettings = nil
        isOnboardingCompleted = false
        
        saveToLocalStorage()
    }
}

// MARK: - Settings Categories

struct OnboardingSettings: Codable {
    var completedSteps: Set<OnboardingStep>
    var selectedPlan: SubscriptionPlan?
    var agreedToTerms: Bool
    var agreedToPrivacyPolicy: Bool
    var enabledNotifications: Bool
    var completedAt: Date?
    
    init() {
        self.completedSteps = []
        self.selectedPlan = nil
        self.agreedToTerms = false
        self.agreedToPrivacyPolicy = false
        self.enabledNotifications = false
        self.completedAt = nil
    }
}

struct KeyboardShortcuts: Codable {
    var globalDictationHotkey: HotkeyConfiguration
    var stopDictationHotkey: HotkeyConfiguration?
    var quickFormatHotkey: HotkeyConfiguration?
    var showMainAppHotkey: HotkeyConfiguration?
    
    init() {
        // Default to fn key as recommended
        self.globalDictationHotkey = HotkeyConfiguration(
            key: .fn,
            modifiers: [],
            description: "Start/Stop Dictation"
        )
        self.stopDictationHotkey = nil
        self.quickFormatHotkey = HotkeyConfiguration(
            key: .f,
            modifiers: [.command, .shift],
            description: "Quick Format Text"
        )
        self.showMainAppHotkey = HotkeyConfiguration(
            key: .h,
            modifiers: [.command, .option],
            description: "Show Hermes"
        )
    }
}

struct PrivacySettings: Codable {
    var isPrivacyModeEnabled: Bool
    var storeDictationHistory: Bool
    var allowAnalytics: Bool
    var allowCloudSync: Bool
    var allowCrashReports: Bool
    var autoDeleteHistoryAfterDays: Int?
    
    init() {
        self.isPrivacyModeEnabled = false
        self.storeDictationHistory = true
        self.allowAnalytics = true
        self.allowCloudSync = true
        self.allowCrashReports = true
        self.autoDeleteHistoryAfterDays = nil
    }
}

struct DictationSettings: Codable {
    var defaultLanguage: String
    var autoFormatting: Bool
    var smartPunctuation: Bool
    var codeMode: Bool
    var voiceActivityThreshold: Float
    var maxRecordingDuration: TimeInterval
    var autoSubmitAfterSilence: Bool
    var preferredModel: String
    
    init() {
        self.defaultLanguage = "en"
        self.autoFormatting = true
        self.smartPunctuation = true
        self.codeMode = false
        self.voiceActivityThreshold = 0.1
        self.maxRecordingDuration = 300 // 5 minutes
        self.autoSubmitAfterSilence = true
        self.preferredModel = "base"
    }
}

struct InterfaceSettings: Codable {
    var theme: AppTheme
    var showMenuBarIcon: Bool
    var showFloatingDictationMarker: Bool
    var animationsEnabled: Bool
    var compactMode: Bool
    var fontSize: FontSize
    
    init() {
        self.theme = .auto
        self.showMenuBarIcon = true
        self.showFloatingDictationMarker = true
        self.animationsEnabled = true
        self.compactMode = false
        self.fontSize = .medium
    }
}

struct TeamSettings: Codable {
    var teamId: String?
    var teamName: String?
    var userRole: TeamRole?
    var sharedDictionaries: [String]
    var allowTeamInsights: Bool
    
    init() {
        self.teamId = nil
        self.teamName = nil
        self.userRole = nil
        self.sharedDictionaries = []
        self.allowTeamInsights = false
    }
}

// MARK: - Supporting Types

struct HotkeyConfiguration: Codable, Equatable {
    let key: KeyboardKey
    let modifiers: Set<KeyboardModifier>
    let description: String
    
    var displayString: String {
        let modifierStrings = modifiers.sorted(by: { $0.sortOrder < $1.sortOrder }).map { $0.symbol }
        return (modifierStrings + [key.symbol]).joined()
    }
}

enum KeyboardKey: String, Codable, CaseIterable {
    case fn = "fn"
    case command = "cmd"
    case space = "Space"
    case enter = "Enter"
    case tab = "Tab"
    case escape = "Escape"
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    case zero = "0", one = "1", two = "2", three = "3", four = "4"
    case five = "5", six = "6", seven = "7", eight = "8", nine = "9"
    case f1 = "F1", f2 = "F2", f3 = "F3", f4 = "F4", f5 = "F5", f6 = "F6"
    case f7 = "F7", f8 = "F8", f9 = "F9", f10 = "F10", f11 = "F11", f12 = "F12"
    
    var symbol: String {
        switch self {
        case .fn: return "fn"
        case .command: return "⌘⌘"
        case .space: return "␣"
        case .enter: return "↩"
        case .tab: return "⇥"
        case .escape: return "⎋"
        default: return rawValue.uppercased()
        }
    }
    
    var displayIcon: String? {
        switch self {
        case .fn: return "globe"
        case .space: return "space"
        case .enter: return "return"
        case .tab: return "arrow.right.to.line"
        case .escape: return "escape"
        default: return nil
        }
    }
    
    var displayText: String? {
        switch self {
        case .fn: return "fn"
        case .space: return "space"
        case .enter: return "return"
        case .tab: return "tab"
        case .escape: return "esc"
        default: return rawValue.uppercased()
        }
    }
}

enum KeyboardModifier: String, Codable, CaseIterable {
    case command = "cmd"
    case option = "opt"
    case shift = "shift"
    case control = "ctrl"
    
    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .control: return "⌃"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .control: return 0
        case .option: return 1
        case .shift: return 2
        case .command: return 3
        }
    }
    
    var displayText: String {
        switch self {
        case .command: return "command"
        case .option: return "option" 
        case .shift: return "shift"
        case .control: return "control"
        }
    }
}


enum SubscriptionPlan: String, Codable, CaseIterable {
    case free = "free"
    case monthly = "monthly"
    case annual = "annual"
    case lifetime = "lifetime"
}

enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"
}

enum FontSize: String, Codable, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
}

enum TeamRole: String, Codable, CaseIterable {
    case member = "member"
    case admin = "admin"
    case owner = "owner"
}

// MARK: - Codable Helper Types

/// Simplified version for JSON storage
private struct StorableUserSettings: Codable {
    let onboardingSettings: OnboardingSettings
    let keyboardShortcuts: KeyboardShortcuts
    let privacySettings: PrivacySettings
    let dictationSettings: DictationSettings
    let interfaceSettings: InterfaceSettings
    let teamSettings: TeamSettings?
    let isOnboardingCompleted: Bool
    let lastSyncDate: Date?
    let deviceId: String
    let appVersion: String
}

// MARK: - UserSettings Extensions

extension UserSettings {
    private func toStorableSettings() -> StorableUserSettings {
        return StorableUserSettings(
            onboardingSettings: onboardingSettings,
            keyboardShortcuts: keyboardShortcuts,
            privacySettings: privacySettings,
            dictationSettings: dictationSettings,
            interfaceSettings: interfaceSettings,
            teamSettings: teamSettings,
            isOnboardingCompleted: isOnboardingCompleted,
            lastSyncDate: lastSyncDate,
            deviceId: deviceId,
            appVersion: appVersion
        )
    }
    
    private func applyStorableSettings(_ settings: StorableUserSettings) {
        self.onboardingSettings = settings.onboardingSettings
        self.keyboardShortcuts = settings.keyboardShortcuts
        self.privacySettings = settings.privacySettings
        self.dictationSettings = settings.dictationSettings
        self.interfaceSettings = settings.interfaceSettings
        self.teamSettings = settings.teamSettings
        self.isOnboardingCompleted = settings.isOnboardingCompleted
        self.lastSyncDate = settings.lastSyncDate
        self.deviceId = settings.deviceId
        self.appVersion = settings.appVersion
    }
}

// MARK: - KeyboardModifier Hashable Conformance

extension KeyboardModifier: Hashable {}