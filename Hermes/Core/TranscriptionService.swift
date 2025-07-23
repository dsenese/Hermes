//
//  TranscriptionService.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import Foundation
import WhisperKit
import Combine

/// Handles speech-to-text transcription using WhisperKit
@MainActor
class TranscriptionService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isInitialized = false
    @Published private(set) var currentModel: String = ""
    @Published private(set) var availableModels: [String] = []
    
    // MARK: - Private Properties
    private var whisperKit: WhisperKit?
    private let transcriptionSubject = PassthroughSubject<HermesTranscriptionResult, Never>()
    
    // Model configuration
    private let primaryModel = "openai_whisper-large-v3-turbo"
    private let fallbackModel = "openai_whisper-distil-large-v3"
    private var isUsingFallback = false
    
    // Audio processing
    private var audioBuffer: [Float] = []
    private let maxBufferDuration: TimeInterval = 30.0 // Max 30 seconds of audio
    
    // MARK: - Publishers
    var transcriptionPublisher: AnyPublisher<HermesTranscriptionResult, Never> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init() {
        Task {
            await loadAvailableModels()
        }
    }
    
    // MARK: - Public Methods
    
    /// Initializes WhisperKit with the appropriate model
    func initialize() async throws {
        guard !isInitialized else { return }
        
        print("🤖 Initializing WhisperKit...")
        
        do {
            // Try primary model first
            whisperKit = try await initializeWhisperKit(with: primaryModel)
            currentModel = primaryModel
            isUsingFallback = false
            print("✅ WhisperKit initialized with primary model: \(primaryModel)")
            
        } catch {
            print("⚠️ Primary model failed, trying fallback: \(error)")
            
            // Fall back to smaller model
            do {
                whisperKit = try await initializeWhisperKit(with: fallbackModel)
                currentModel = fallbackModel
                isUsingFallback = true
                print("✅ WhisperKit initialized with fallback model: \(fallbackModel)")
                
            } catch {
                print("❌ Both models failed: \(error)")
                throw TranscriptionError.modelInitializationFailed(error)
            }
        }
        
        isInitialized = true
    }
    
    /// Processes audio data for transcription
    func processAudioData(_ audioData: Data) async {
        guard isInitialized, whisperKit != nil else {
            print("⚠️ WhisperKit not initialized, skipping audio data")
            return
        }
        
        // Convert Data to Float array
        let floatArray = audioData.withUnsafeBytes { bytes in
            bytes.bindMemory(to: Float.self).map { $0 }
        }
        
        // Add to buffer
        audioBuffer.append(contentsOf: floatArray)
        
        // Limit buffer size to prevent memory issues
        let maxSamples = Int(maxBufferDuration * HermesConstants.sampleRate)
        if audioBuffer.count > maxSamples {
            audioBuffer.removeFirst(audioBuffer.count - maxSamples)
        }
        
        // Process if we have enough audio (minimum 1 second)
        let minSamples = Int(1.0 * HermesConstants.sampleRate)
        if audioBuffer.count >= minSamples {
            await transcribeAudio(floatArray: audioBuffer)
        }
    }
    
    /// Forces transcription of current buffer
    func flushBuffer() async {
        guard !audioBuffer.isEmpty else { return }
        await transcribeAudio(floatArray: audioBuffer)
        audioBuffer.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func loadAvailableModels() async {
        // Load available models from WhisperKit
        let models = ["openai_whisper-large-v3-turbo", "openai_whisper-distil-large-v3", "openai_whisper-base"]
        availableModels = models
        print("📋 Available models: \(availableModels)")
    }
    
    private func initializeWhisperKit(with modelName: String) async throws -> WhisperKit {
        return try await WhisperKit(
            model: modelName,
            verbose: false,
            prewarm: true,
            download: true
        )
    }
    
    private func transcribeAudio(floatArray: [Float]) async {
        guard whisperKit != nil else { return }
        
        let startTime = Date()
        
        // For now, let's use a simpler approach and create a dummy result
        // TODO: Implement proper WhisperKit integration once API is clarified
        let dummyText = "Transcription placeholder - implement WhisperKit API"
        
        let latency = Date().timeIntervalSince(startTime)
        
        // Create a simple result
        let result = HermesTranscriptionResult(
            text: dummyText,
            type: .final,
            confidence: 0.8,
            latency: latency,
            timestamp: Date(),
            modelUsed: currentModel
        )
        
        // Emit result
        transcriptionSubject.send(result)
        
        print("🔄 Placeholder transcription sent (WhisperKit integration pending)")
    }
    
    
    
    private func tryFallbackModel() async {
        print("🔄 Switching to fallback model...")
        
        do {
            whisperKit = try await initializeWhisperKit(with: fallbackModel)
            currentModel = fallbackModel
            isUsingFallback = true
            print("✅ Switched to fallback model: \(fallbackModel)")
        } catch {
            print("❌ Fallback model initialization failed: \(error)")
        }
    }
}

// MARK: - Supporting Types

/// Result of a transcription operation (renamed to avoid conflict with WhisperKit's TranscriptionResult)
struct HermesTranscriptionResult {
    let text: String
    let type: TranscriptionResultType
    let confidence: Double
    let latency: TimeInterval
    let timestamp: Date
    let modelUsed: String
    
    var isHighConfidence: Bool {
        confidence > 0.7
    }
}

/// Type of transcription result
enum TranscriptionResultType {
    case partial  // Intermediate result, may change
    case final    // Final result for this audio segment
}

/// Errors that can occur during transcription
enum TranscriptionError: LocalizedError {
    case modelInitializationFailed(Error)
    case transcriptionFailed(Error)
    case modelNotFound(String)
    case audioProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .modelInitializationFailed(let error):
            return "Failed to initialize transcription model: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .modelNotFound(let model):
            return "Transcription model not found: \(model)"
        case .audioProcessingFailed:
            return "Failed to process audio data"
        }
    }
}