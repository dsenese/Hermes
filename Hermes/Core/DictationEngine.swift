//
//  DictationEngine.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import Foundation
import Combine
import AppKit

/// Main dictation engine that coordinates audio capture, transcription, and text injection
class DictationEngine: ObservableObject {
    // MARK: - Singleton
    private static var _shared: DictationEngine?
    
    @MainActor
    static var shared: DictationEngine {
        if let instance = _shared {
            return instance
        }
        print("🔄 Lazy loading DictationEngine.shared...")
        let instance = DictationEngine()
        _shared = instance
        return instance
    }
    // MARK: - Published Properties
    @Published private(set) var isActive = false
    @Published private(set) var currentTranscription = ""
    @Published private(set) var partialTranscription = ""
    @Published private(set) var isProcessing = false
    @Published private(set) var errorMessage: String?
    
    // Context tracking to differentiate global vs local dictation
    private var currentContext: DictationContext = .global
    
    // Public read-only access to current context
    var dictationContext: DictationContext {
        currentContext
    }
    
    // MARK: - Dependencies
    let audioManager: AudioManager
    let transcriptionService: TranscriptionService
    private let textInjector: TextInjector
    private let contextDetector: ApplicationContextDetector
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var transcriptionTask: Task<Void, Never>?
    
    // Performance tracking
    private var startTime: Date?
    private var latencyMeasurements: [TimeInterval] = []
    
    // MARK: - Initialization
    @MainActor
    private init(
        audioManager: AudioManager? = nil,
        transcriptionService: TranscriptionService? = nil,
        textInjector: TextInjector? = nil,
        contextDetector: ApplicationContextDetector? = nil
    ) {
        print("🚀 Initializing DictationEngine...")
        
        self.audioManager = audioManager ?? AudioManager()
        print("✅ AudioManager initialized")
        
        self.transcriptionService = transcriptionService ?? TranscriptionService.shared
        print("✅ TranscriptionService initialized")
        
        self.textInjector = textInjector ?? TextInjector()
        print("✅ TextInjector initialized")
        
        self.contextDetector = contextDetector ?? ApplicationContextDetector()
        print("✅ ApplicationContextDetector initialized")
        
        setupSubscriptions()
        print("✅ DictationEngine initialization complete")
        // Don't setup global hotkey here - let AppDelegate handle it
    }
    
    // MARK: - Public Methods
    
    /// Starts the dictation session
    @MainActor
    func startDictation(context: DictationContext = .global) async {
        guard !isActive else { return }
        
        currentContext = context
        print("🚀 Starting dictation with context: \(context)")
        
        do {
            // Clear previous state
            currentTranscription = ""
            partialTranscription = ""
            errorMessage = nil
            startTime = Date()
            
            // Reset transcription service state
            transcriptionService.resetState()
            
            // Start audio capture
            try await audioManager.startRecording()
            
            // Initialize transcription service if not already done
            if !transcriptionService.isInitialized {
                try await transcriptionService.initialize()
            }
            
            isActive = true
            isProcessing = true
            
            print("🚀 Dictation session started")
            
        } catch {
            errorMessage = "Failed to start dictation: \(error.localizedDescription)"
            print("❌ Dictation start failed: \(error)")
        }
    }
    
    /// Stops the dictation session and processes the complete audio
    @MainActor
    func stopDictation() async {
        guard isActive else { return }
        
        isActive = false
        isProcessing = true // Keep processing true while transcribing
        
        // Stop audio capture - this should preserve all buffered audio
        audioManager.stopRecording()
        
        print("⏹️ Audio recording stopped - starting transcription...")
        
        // Cancel ongoing transcription task
        transcriptionTask?.cancel()
        
        // Get current application context for AI formatting
        let currentBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        
        // Wait for complete transcription with application context (this now returns the actual result)
        let finalTranscription = await transcriptionService.transcribeCompleteSession(appBundleId: currentBundleId)
        
        // Inject final transcription only if we have meaningful text
        if !finalTranscription.isEmpty {
            currentTranscription = finalTranscription // Update for consistency
            await injectFinalText(finalTranscription)
        } else {
            print("🔄 No meaningful transcription to inject")
        }
        
        isProcessing = false
        
        // Log performance metrics
        if let startTime = startTime {
            let sessionDuration = Date().timeIntervalSince(startTime)
            print("📊 Session completed - Duration: \(String(format: "%.2f", sessionDuration))s")
        }
        
        // Reset state
        currentTranscription = ""
        partialTranscription = ""
        latencyMeasurements.removeAll()
        
        print("✅ Dictation session completed")
    }
    
    /// Toggles dictation on/off
    @MainActor
    func toggleDictation() async {
        if isActive {
            await stopDictation()
        } else {
            await startDictation()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Subscribe to audio data for transcription
        audioManager.audioDataPublisher
            .sink { [weak self] audioData in
                Task { @MainActor in
                    await self?.processAudioData(audioData)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to transcription results
        transcriptionService.transcriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                Task { @MainActor in
                    await self?.handleTranscriptionResult(result)
                }
            }
            .store(in: &cancellables)
    }
    
    private func processAudioData(_ audioData: Data) async {
        guard isActive else { return }
        
        // Simply accumulate audio data - no transcription during recording
        await transcriptionService.processAudioData(audioData)
    }
    
    @MainActor
    private func handleTranscriptionResult(_ result: HermesTranscriptionResult) async {
        switch result.type {
        case .partial:
            partialTranscription = result.text
            
        case .final:
            // Add final transcription to our current text
            if !result.text.isEmpty {
                if currentTranscription.isEmpty {
                    currentTranscription = result.text
                } else {
                    currentTranscription += " " + result.text
                }
            }
            
            // Clear partial transcription
            partialTranscription = ""
            
            // Only inject text for real-time updates if still actively dictating
            // Skip injection if we're in the final processing phase
            if isActive {
                await injectTranscriptionUpdate()
            } else {
                print("🔄 Skipping real-time injection - dictation stopped, waiting for final transcription")
            }
        }
    }
    
    private func injectTranscriptionUpdate() async {
        guard !currentTranscription.isEmpty else { return }
        
        // Only inject text for global dictation context
        if currentContext == .global {
            await textInjector.replaceCurrentDictation(with: currentTranscription)
            print("🔄 Text injected (global): \(currentTranscription.prefix(30))...")
        } else {
            print("🔄 Skipping text injection for local context: \(currentContext)")
        }
    }
    
    private func injectFinalText(_ text: String) async {
        guard !text.isEmpty else { 
            print("🔄 No text to inject")
            return 
        }
        
        // Only inject text for global dictation context
        if currentContext == .global {
            await textInjector.finalizeDictation(with: text)
            print("✅ Final text injected (global): \(text.prefix(50))...")
        } else {
            print("✅ Skipping final text injection for local context: \(currentContext)")
        }
    }
    
    deinit {
        transcriptionTask?.cancel()
        // Don't unregister hotkey here - let AppDelegate manage it
    }
    
    /// Update the global hotkey when settings change (called by AppDelegate)
    func updateGlobalHotkey(_ hotkey: HotkeyConfiguration) {
        // This will be called by AppDelegate when hotkey changes
        print("🔄 DictationEngine notified of hotkey update to: \(hotkey.displayString)")
    }
}

// MARK: - Supporting Types

/// Represents the current state of dictation
enum DictationState {
    case idle
    case listening
    case processing
    case error(String)
}

/// Represents the context where dictation is being performed
enum DictationContext {
    case global    // Global dictation (inject into active app)
    case local     // Local dictation (e.g., Notes view)
}

/// Performance metrics for monitoring
struct DictationMetrics {
    let sessionDuration: TimeInterval
    let averageLatency: TimeInterval
    let totalCharacters: Int
    let transcriptionAccuracy: Double?
    
    var charactersPerSecond: Double {
        sessionDuration > 0 ? Double(totalCharacters) / sessionDuration : 0
    }
}
