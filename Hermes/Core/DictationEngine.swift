//
//  DictationEngine.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import Foundation
import Combine

/// Main dictation engine that coordinates audio capture, transcription, and text injection
@MainActor
class DictationEngine: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isActive = false
    @Published private(set) var currentTranscription = ""
    @Published private(set) var partialTranscription = ""
    @Published private(set) var isProcessing = false
    @Published private(set) var errorMessage: String?
    
    // MARK: - Dependencies
    let audioManager: AudioManager
    let transcriptionService: TranscriptionService
    private let textInjector: TextInjector
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var transcriptionTask: Task<Void, Never>?
    
    // Performance tracking
    private var startTime: Date?
    private var latencyMeasurements: [TimeInterval] = []
    
    // MARK: - Initialization
    init(
        audioManager: AudioManager? = nil,
        transcriptionService: TranscriptionService? = nil,
        textInjector: TextInjector? = nil
    ) {
        self.audioManager = audioManager ?? AudioManager()
        self.transcriptionService = transcriptionService ?? TranscriptionService()
        self.textInjector = textInjector ?? TextInjector()
        
        setupSubscriptions()
        setupGlobalHotkey()
    }
    
    // MARK: - Public Methods
    
    /// Starts the dictation session
    func startDictation() async {
        guard !isActive else { return }
        
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
            
            // Initialize transcription service
            try await transcriptionService.initialize()
            
            isActive = true
            isProcessing = true
            
            print("🚀 Dictation session started")
            
        } catch {
            errorMessage = "Failed to start dictation: \(error.localizedDescription)"
            print("❌ Dictation start failed: \(error)")
        }
    }
    
    /// Stops the dictation session and processes the complete audio
    func stopDictation() async {
        guard isActive else { return }
        
        isActive = false
        isProcessing = true // Keep processing true while transcribing
        
        // Stop audio capture
        audioManager.stopRecording()
        
        print("⏹️ Audio recording stopped - starting transcription...")
        
        // Transcribe the complete recorded session
        await transcriptionService.transcribeCompleteSession()
        
        // Cancel ongoing transcription task
        transcriptionTask?.cancel()
        
        // Wait a moment for transcription result to arrive
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Inject final transcription if we have any
        if !currentTranscription.isEmpty {
            await injectFinalText()
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
            
            // Inject text immediately for real-time experience
            await injectTranscriptionUpdate()
        }
    }
    
    private func injectTranscriptionUpdate() async {
        guard !currentTranscription.isEmpty else { return }
        
        await textInjector.replaceCurrentDictation(with: currentTranscription)
    }
    
    private func injectFinalText() async {
        guard !currentTranscription.isEmpty else { return }
        
        await textInjector.finalizeDictation(with: currentTranscription)
        print("✅ Final text injected: \(currentTranscription.prefix(50))...")
    }
    
    deinit {
        transcriptionTask?.cancel()
        Task { @MainActor in
            GlobalHotkeyManager.shared.unregisterHotkey()
        }
    }
    
    // MARK: - Global Hotkey Integration
    
    private func setupGlobalHotkey() {
        let hotkeyManager = GlobalHotkeyManager.shared
        let currentHotkey = UserSettings.shared.keyboardShortcuts.globalDictationHotkey
        
        // Register the global hotkey for hold-to-talk dictation control
        hotkeyManager.registerHotkey(currentHotkey, 
            onPressed: {
                Task { @MainActor in
                    await self.startDictation()
                }
            },
            onReleased: {
                Task { @MainActor in
                    await self.stopDictation()
                }
            }
        )
        
        print("🔥 Global hotkey registered for hold-to-talk: \(currentHotkey.displayString)")
    }
    
    /// Update the global hotkey when settings change
    func updateGlobalHotkey(_ hotkey: HotkeyConfiguration) {
        GlobalHotkeyManager.shared.updateHotkey(hotkey)
        print("🔄 Updated global hotkey to: \(hotkey.displayString)")
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