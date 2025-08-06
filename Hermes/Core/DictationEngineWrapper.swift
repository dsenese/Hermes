//
//  DictationEngineWrapper.swift
//  Hermes
//
//  Created by Claude Code on 7/30/25.
//

import Foundation
import SwiftUI

/// Wrapper to defer DictationEngine.shared access until actually needed
/// This prevents early initialization that can block the UI during app startup
@MainActor
class DictationEngineWrapper: ObservableObject {
    private var _engine: DictationEngine?
    
    var engine: DictationEngine {
        if let engine = _engine {
            return engine
        }
        
        print("🔄 Lazy loading DictationEngine.shared...")
        let engine = DictationEngine.shared
        _engine = engine
        return engine
    }
}