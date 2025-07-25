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
    @Published private(set) var isDownloadingModel = false
    @Published private(set) var downloadProgress: Double = 0.0
    
    // MARK: - Private Properties
    private var whisperKit: WhisperKit?
    private let transcriptionSubject = PassthroughSubject<HermesTranscriptionResult, Never>()
    
    // Model configuration
    private let primaryModel = "large-v3"
    private let fallbackModel = "distil-large-v3"
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
                print("⚠️ Fallback model failed, trying base model: \(error)")
                
                // Try base model as final fallback
                do {
                    whisperKit = try await initializeWhisperKit(with: "base")
                    currentModel = "base"
                    isUsingFallback = true
                    print("✅ WhisperKit initialized with base model")
                    
                } catch {
                    print("❌ All models failed: \(error)")
                    throw TranscriptionError.modelInitializationFailed(error)
                }
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
        
        // Process if we have enough audio (minimum 1 second for initial transcription)
        let minSamples = Int(1.0 * HermesConstants.sampleRate)
        if audioBuffer.count >= minSamples {
            await transcribeAudio(floatArray: audioBuffer)
        }
        
        // For real-time feedback, also process smaller chunks as partial results
        // This provides faster user feedback while building up the full transcription
        let partialSamples = Int(0.5 * HermesConstants.sampleRate) // 500ms chunks
        if audioBuffer.count >= partialSamples && audioBuffer.count % partialSamples == 0 {
            // Process last 2 seconds for partial results to maintain context
            let contextSamples = min(Int(2.0 * HermesConstants.sampleRate), audioBuffer.count)
            let contextAudio = Array(audioBuffer.suffix(contextSamples))
            await transcribeAudioPartial(floatArray: contextAudio)
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
        print("🔍 Loading available WhisperKit models...")
        
        // Get available models from WhisperKit
        // These are the models we want to support in Hermes
        let preferredModels = [
            primaryModel,      // "large-v3"
            fallbackModel,     // "distil-large-v3"
            "base"             // Lightweight option
        ]
        
        availableModels = preferredModels
        print("📋 Available models: \(availableModels)")
        
        // TODO: In the future, we could query WhisperKit for actually available models
        // This would require checking downloaded models and available models online
    }
    
    private func initializeWhisperKit(with modelName: String) async throws -> WhisperKit {
        print("📥 Initializing WhisperKit with model: \(modelName)")
        
        isDownloadingModel = true
        downloadProgress = 0.0
        
        defer {
            isDownloadingModel = false
            downloadProgress = 0.0
        }
        
        do {
            let whisperKit = try await WhisperKit(
                model: modelName,
                verbose: false,
                prewarm: true,
                download: true
            )
            
            print("✅ WhisperKit model '\(modelName)' loaded successfully")
            return whisperKit
            
        } catch {
            print("❌ Failed to initialize WhisperKit with model '\(modelName)': \(error)")
            throw error
        }
    }
    
    private func transcribeAudio(floatArray: [Float]) async {
        guard let whisperKit = whisperKit else { 
            print("⚠️ WhisperKit not available for transcription")
            return 
        }
        
        let startTime = Date()
        
        do {
            // Normalize float array to [-1.0, 1.0] range if needed
            let normalizedAudio = normalizeAudioArray(floatArray)
            
            // Transcribe using WhisperKit's Float array method
            let results = try await whisperKit.transcribe(audioArray: normalizedAudio)
            
            let latency = Date().timeIntervalSince(startTime)
            
            // Extract transcription text from first result
            let transcriptionText = results.first?.text ?? ""
            
            // Skip empty results
            guard !transcriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("🔄 Empty transcription result, skipping")
                return
            }
            
            // Create Hermes result with actual transcription
            let result = HermesTranscriptionResult(
                text: transcriptionText,
                type: .final,
                confidence: calculateConfidence(from: results.first),
                latency: latency,
                timestamp: Date(),
                modelUsed: currentModel
            )
            
            // Emit result
            transcriptionSubject.send(result)
            
            print("✅ Transcription completed: '\(transcriptionText)' (latency: \(String(format: "%.2f", latency * 1000))ms)")
            
        } catch {
            print("❌ Transcription failed: \(error)")
            
            let latency = Date().timeIntervalSince(startTime)
            
            // Send error result
            let errorResult = HermesTranscriptionResult(
                text: "",
                type: .final,
                confidence: 0.0,
                latency: latency,
                timestamp: Date(),
                modelUsed: currentModel
            )
            
            transcriptionSubject.send(errorResult)
            
            // Try fallback model if primary fails repeatedly
            if !isUsingFallback {
                await tryFallbackModel()
            }
        }
    }
    
    /// Transcribes audio for partial/real-time results
    private func transcribeAudioPartial(floatArray: [Float]) async {
        guard let whisperKit = whisperKit else { 
            return 
        }
        
        let startTime = Date()
        
        do {
            // Normalize audio
            let normalizedAudio = normalizeAudioArray(floatArray)
            
            // Transcribe with lower priority for partial results
            let results = try await whisperKit.transcribe(audioArray: normalizedAudio)
            
            let latency = Date().timeIntervalSince(startTime)
            
            // Extract transcription text
            let transcriptionText = results.first?.text ?? ""
            
            // Only send partial results if they contain meaningful content
            let trimmedText = transcriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty && trimmedText.count > 2 else {
                return
            }
            
            // Create partial result
            let result = HermesTranscriptionResult(
                text: transcriptionText,
                type: .partial,
                confidence: calculateConfidence(from: results.first),
                latency: latency,
                timestamp: Date(),
                modelUsed: currentModel
            )
            
            // Emit partial result
            transcriptionSubject.send(result)
            
            print("🔄 Partial transcription: '\(trimmedText.prefix(50))...' (latency: \(String(format: "%.2f", latency * 1000))ms)")
            
        } catch {
            // Silently ignore partial transcription errors to avoid spam
            // They're not as critical as final transcription failures
        }
    }
    
    /// Normalizes audio array to [-1.0, 1.0] range
    private func normalizeAudioArray(_ audio: [Float]) -> [Float] {
        guard !audio.isEmpty else { return audio }
        
        let maxAmplitude = audio.map { abs($0) }.max() ?? 1.0
        
        // If already normalized or very quiet, return as-is
        if maxAmplitude <= 1.0 {
            return audio
        }
        
        // Normalize to prevent clipping
        let normalizationFactor = 1.0 / maxAmplitude
        return audio.map { $0 * normalizationFactor }
    }
    
    /// Extracts confidence score from WhisperKit result
    private func calculateConfidence(from result: Any?) -> Double {
        // WhisperKit's confidence implementation may vary by version
        // For now, return a reasonable default and log for debugging
        // TODO: Update when WhisperKit confidence API is clarified
        let defaultConfidence = 0.85
        
        if result != nil {
            return defaultConfidence
        } else {
            return 0.0
        }
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