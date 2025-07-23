//
//  Constants.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import Foundation

struct HermesConstants {
    // MARK: - Audio Configuration
    static let sampleRate: Double = 16000.0
    static let channels: Int = 1
    static let chunkDuration: TimeInterval = 5.0
    
    // MARK: - Performance Targets
    static let maxLatency: TimeInterval = 0.4 // 400ms target
    static let maxCPUUsage: Double = 0.04 // 4% target
    static let maxAppSize: Int = 400 * 1024 * 1024 // 400MB
    static let maxLaunchTime: TimeInterval = 4.0 // 4s target
    
    // MARK: - Pricing
    static let monthlyPrice: Decimal = 10.00
    static let annualPrice: Decimal = 96.00
    static let lifetimePrice: Decimal = 150.00
    static let trialDuration: TimeInterval = 14 * 24 * 60 * 60 // 14 days
    
    // MARK: - Usage Limits
    static let monthlyCharacterLimit: Int = 200_000
    static let maxSessionDuration: TimeInterval = 60 * 60 // 1 hour
    
    // MARK: - UI Configuration
    static let primaryAccentColor = "#CCFF00" // Neon Robin
    static let animationDuration: TimeInterval = 0.3
    static let popupWidth: Double = 320
    static let popupHeight: Double = 200
    
    // MARK: - Default Hotkeys
    static let defaultHotkey = "⌘⌘" // Double Command key
    static let alternateHotkey = "⌃⌃" // Double Control key
    
    // MARK: - Model Configuration
    static let primaryModel = "openai_whisper-large-v3-turbo"
    static let fallbackModel = "openai_whisper-distil-large-v3"
    static let confidenceThreshold: Double = 0.7
    
    // MARK: - Voice Activity Detection
    static let vadEnergyThreshold: Float = 0.01
    static let vadSilenceThreshold: TimeInterval = 0.5
    static let vadMinSpeechDuration: TimeInterval = 0.3
    
    // MARK: - App Information
    static let appName = "Hermes"
    static let appVersion = "1.0.0"
    static let appBundleID = "com.dominicsenese.Hermes"
    
    // MARK: - Debug Configuration
    static let enableVerboseLogging = false
    static let enablePerformanceLogging = true
    static let maxLogEntries = 1000
}