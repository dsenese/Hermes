//
//  Constants.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import Foundation

struct HermesConstants {
    // Audio Configuration
    static let sampleRate: Double = 16000.0
    static let channels: Int = 1
    static let chunkDuration: TimeInterval = 5.0
    
    // Performance Targets
    static let maxLatency: TimeInterval = 0.4 // 400ms target
    static let maxCPUUsage: Double = 0.04 // 4% target
    static let maxAppSize: Int = 400 * 1024 * 1024 // 400MB
    
    // Pricing
    static let monthlyPrice: Decimal = 10.00
    static let annualPrice: Decimal = 96.00
    static let lifetimePrice: Decimal = 150.00
}