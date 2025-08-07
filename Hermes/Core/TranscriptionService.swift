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
class TranscriptionService: ObservableObject {
    // MARK: - Singleton
    static let shared = TranscriptionService()
    // MARK: - Published Properties
    @Published private(set) var isInitialized = false
    @Published private(set) var currentModel: String = ""
    @Published private(set) var availableModels: [String] = []
    @Published private(set) var isDownloadingModel = false
    @Published private(set) var downloadProgress: Double = 0.0
    
    // MARK: - Private Properties
    private var whisperKit: WhisperKit?
    private let transcriptionSubject = PassthroughSubject<HermesTranscriptionResult, Never>()
    
    // Model configuration - Use ONLY Large-V3 for best accuracy and performance
    // Large-V3 provides optimal accuracy for production use (~1.5GB, requires Apple Silicon)
    private let targetModel = "openai_whisper-large-v3"  // Production model - no fallback
    
    // Audio processing
    private var audioBuffer: [Float] = []
    private let maxBufferDuration: TimeInterval = 30.0 // Max 30 seconds of audio
    private var lastTranscribedIndex: Int = 0 // Track what we've already transcribed
    private var isTranscribing = false // Prevent concurrent transcriptions
    
    // MARK: - Publishers
    var transcriptionPublisher: AnyPublisher<HermesTranscriptionResult, Never> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    private init() {
        // Don't load models during init to avoid blocking the main thread
        // Models will be loaded lazily when initialize() is called
    }
    
    // MARK: - Public Methods
    
    /// Initializes WhisperKit with the appropriate model
    func initialize() async throws {
        guard !isInitialized else { return }
        
        // Load available models first if not already loaded
        if availableModels.isEmpty {
            await loadAvailableModels()
        }
        
        print("🤖 Initializing WhisperKit with openai_whisper-large-v3 model...")
        
        do {
            // Initialize with openai_whisper-large-v3 model only - no fallbacks
            whisperKit = try await initializeWhisperKit(with: targetModel)
            currentModel = targetModel
            print("✅ WhisperKit initialized successfully with: \(targetModel)")
            
        } catch {
            print("❌ Failed to initialize WhisperKit with \(targetModel): \(error)")
            print("💡 Model will be downloaded from argmaxinc/whisperkit-coreml repository")
            throw TranscriptionError.modelInitializationFailed(error)
        }
        
        isInitialized = true
    }
    
    /// Accumulates audio data during recording (does not transcribe immediately)
    func processAudioData(_ audioData: Data) async {
        guard isInitialized else {
            print("⚠️ TranscriptionService not initialized, skipping audio data")
            return
        }
        
        // Convert Data to Float array
        let floatArray = audioData.withUnsafeBytes { bytes in
            bytes.bindMemory(to: Float.self).map { $0 }
        }
        
        // Debug: Check the actual audio levels we're receiving
        let maxLevel = floatArray.map { abs($0) }.max() ?? 0.0
        let avgLevel = floatArray.map { abs($0) }.reduce(0, +) / Float(floatArray.count)
        
        // Add to buffer without transcribing
        audioBuffer.append(contentsOf: floatArray)
        
        // Limit buffer size to prevent memory issues
        let maxSamples = Int(maxBufferDuration * HermesConstants.sampleRate)
        if audioBuffer.count > maxSamples {
            let overflow = audioBuffer.count - maxSamples
            audioBuffer.removeFirst(overflow)
        }
        
        let duration = Double(audioBuffer.count) / HermesConstants.sampleRate
        print("🎤 Accumulating audio: \(floatArray.count) new samples, total: \(audioBuffer.count) samples (\(String(format: "%.1f", duration))s)")
        print("🎤 Chunk levels: max=\(String(format: "%.6f", maxLevel)), avg=\(String(format: "%.6f", avgLevel))")
    }
    
    /// Transcribes the entire accumulated audio buffer (called when recording stops)
    /// Returns the transcription result directly instead of just publishing it
    func transcribeCompleteSession() async -> String {
        guard !audioBuffer.isEmpty else { 
            print("⚠️ No audio data to transcribe")
            return ""
        }
        
        guard !isTranscribing else {
            print("⚠️ Already transcribing, ignoring request")
            return ""
        }
        
        let totalDuration = Double(audioBuffer.count) / HermesConstants.sampleRate
        print("🎯 Starting transcription of complete session: \(audioBuffer.count) samples (\(String(format: "%.2f", totalDuration))s)")
        
        // Only transcribe if we have enough meaningful audio (at least 0.5 seconds)
        guard totalDuration >= 0.5 else {
            print("⚠️ Audio too short to transcribe: \(String(format: "%.2f", totalDuration))s")
            audioBuffer.removeAll()
            return ""
        }
        
        isTranscribing = true
        let result = await transcribeAudioDirectly(floatArray: audioBuffer)
        audioBuffer.removeAll()
        lastTranscribedIndex = 0
        isTranscribing = false
        
        return result
    }
    
    /// Direct transcription that returns result instead of publishing
    private func transcribeAudioDirectly(floatArray: [Float]) async -> String {
        guard let whisperKit = whisperKit else { 
            print("⚠️ WhisperKit not available for transcription")
            return ""
        }
        
        let startTime = Date()
        
        do {
            // Normalize float array to [-1.0, 1.0] range if needed
            let normalizedAudio = normalizeAudioArray(floatArray)
            
            // Check audio levels to ensure we have meaningful audio
            let maxAmplitude = normalizedAudio.map { abs($0) }.max() ?? 0.0
            let avgAmplitude = normalizedAudio.map { abs($0) }.reduce(0, +) / Float(normalizedAudio.count)
            
            print("🎤 Transcribing audio: \(normalizedAudio.count) samples, duration: \(String(format: "%.2f", Double(normalizedAudio.count) / HermesConstants.sampleRate))s")
            print("🎤 Audio levels: max=\(String(format: "%.4f", maxAmplitude)), avg=\(String(format: "%.4f", avgAmplitude))")
            
            // DIAGNOSTIC: Analyze audio distribution to understand potential cutoff causes
            let sampleRate = HermesConstants.sampleRate
            let duration = Double(normalizedAudio.count) / sampleRate
            let segmentDuration = 0.5 // Analyze in 0.5 second segments
            let samplesPerSegment = Int(segmentDuration * sampleRate)
            
            print("🔍 AUDIO ANALYSIS - Analyzing \(String(format: "%.1f", duration))s of audio in \(String(format: "%.1f", segmentDuration))s segments:")
            for i in stride(from: 0, to: normalizedAudio.count, by: samplesPerSegment) {
                let endIndex = min(i + samplesPerSegment, normalizedAudio.count)
                let segment = Array(normalizedAudio[i..<endIndex])
                let segmentMax = segment.map { abs($0) }.max() ?? 0.0
                let segmentAvg = segment.map { abs($0) }.reduce(0, +) / Float(segment.count)
                let segmentTime = Double(i) / sampleRate
                print("🔍   \(String(format: "%.1f", segmentTime))s-\(String(format: "%.1f", segmentTime + Double(endIndex - i) / sampleRate))s: max=\(String(format: "%.4f", segmentMax)), avg=\(String(format: "%.4f", segmentAvg))")
            }
            
            // Skip transcription if audio is too quiet (likely silence)
            // Lower threshold for natural microphone input levels
            guard avgAmplitude > 0.00001 else {
                print("🔇 Audio too quiet (avg: \(String(format: "%.6f", avgAmplitude))), skipping transcription")
                return ""
            }
            
            // ENHANCED: Add longer silence padding and use aggressive audio preprocessing
            // to ensure WhisperKit processes the complete speech even if user releases hotkey immediately
            let paddingSamples = Int(1.0 * sampleRate) // Increased to 1.0 second of silence
            
            // Apply gentle audio normalization to ensure consistent levels throughout
            let maxLevel = normalizedAudio.map { abs($0) }.max() ?? 1.0
            let targetLevel: Float = 0.3 // Target peak level
            let gainFactor = maxLevel > 0.01 ? min(targetLevel / maxLevel, 3.0) : 1.0 // Limit gain to 3x max
            
            let amplifiedAudio = normalizedAudio.map { sample in
                let amplified = sample * gainFactor
                // Soft limiting to prevent clipping
                return amplified > 0.95 ? 0.95 : (amplified < -0.95 ? -0.95 : amplified)
            }
            
            // Add extended silence padding
            let paddedAudio = amplifiedAudio + Array(repeating: Float(0.0), count: paddingSamples)
            
            print("🔧 ENHANCED PREPROCESSING:")
            print("🔧   Applied gain factor: \(String(format: "%.2f", gainFactor))x")
            print("🔧   Original audio: \(normalizedAudio.count) samples (\(String(format: "%.2f", Double(normalizedAudio.count) / sampleRate))s)")
            print("🔧   Padded audio: \(paddedAudio.count) samples (\(String(format: "%.2f", Double(paddedAudio.count) / sampleRate))s)")
            print("🔧   Original max level: \(String(format: "%.4f", maxLevel))")
            print("🔧   Amplified max level: \(String(format: "%.4f", amplifiedAudio.map { abs($0) }.max() ?? 0.0))")
            
            // Transcribe using WhisperKit with the enhanced audio
            let results = try await whisperKit.transcribe(audioArray: paddedAudio)
            
            // DIAGNOSTIC: Let's examine all the results returned by WhisperKit
            print("🔍 WhisperKit returned \(results.count) result(s)")
            for (index, result) in results.enumerated() {
                print("🔍 Result \(index): '\(result.text)' (segments: \(result.segments.count))")
                for (segIndex, segment) in result.segments.enumerated() {
                    print("🔍   Segment \(segIndex): '\(segment.text)' (\(String(format: "%.2f", segment.start))s - \(String(format: "%.2f", segment.end))s)")
                }
            }
            
            // REVERT: The segment extraction is corrupting text, just use the original result.text
            // WhisperKit's result.text already contains the clean transcription
            var fullTranscription = ""
            if let firstResult = results.first {
                // Just use the original result.text - it's already clean
                fullTranscription = firstResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("🔧 REVERTED: Using original result.text: '\(fullTranscription)'")
            }
            
            let latency = Date().timeIntervalSince(startTime)
            
            // Use the concatenated segments if available, otherwise fall back to original method  
            let transcriptionText = !fullTranscription.isEmpty ? fullTranscription : results.first?.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            
            print("🔍 WhisperKit returned: '\(transcriptionText)' (latency: \(String(format: "%.2f", latency * 1000))ms)")
            print("🔧 EXPERIMENTAL: Used concatenated segments: \(!fullTranscription.isEmpty)")
            print("🔍 Result length: \(transcriptionText.count), characters: \(Array(transcriptionText))")
            
            // Check if result is just dots or other meaningless patterns
            let onlyDots = transcriptionText.allSatisfy { $0 == "." }
            let onlyWhitespace = transcriptionText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
            
            // Skip empty results or common false positives
            guard !transcriptionText.isEmpty,
                  !onlyDots,
                  !onlyWhitespace,
                  transcriptionText.lowercased() != "thank you",
                  transcriptionText.lowercased() != "thanks",
                  transcriptionText.count > 2 else {
                print("🔄 Skipping invalid result: '\(transcriptionText)' (dots: \(onlyDots), empty: \(onlyWhitespace), length: \(transcriptionText.count))")
                return ""
            }
            
            print("✅ Transcription completed: '\(transcriptionText)'")
            
            // Also publish for any listeners
            let result = HermesTranscriptionResult(
                text: transcriptionText,
                type: .final,
                confidence: calculateConfidence(from: results.first),
                latency: latency,
                timestamp: Date(),
                modelUsed: currentModel
            )
            transcriptionSubject.send(result)
            
            return transcriptionText
            
        } catch {
            print("❌ Transcription error: \(error)")
            return ""
        }
    }
    
    /// Resets the transcription service state
    func resetState() {
        audioBuffer.removeAll()
        lastTranscribedIndex = 0
        isTranscribing = false
        print("🔄 Transcription service state reset")
    }
    
    /// Returns current buffer information for debugging
    func getBufferInfo() -> (samples: Int, duration: Double) {
        let duration = Double(audioBuffer.count) / HermesConstants.sampleRate
        return (audioBuffer.count, duration)
    }
    
    // MARK: - Private Methods
    
    private func loadAvailableModels() async {
        print("🔍 Loading available WhisperKit models...")
        
        // Get available models from WhisperKit
        // We only support openai_whisper-large-v3 in production
        let preferredModels = [
            targetModel        // "openai_whisper-large-v3"
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
            // Initialize WhisperKit with optimized settings for <400ms performance
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
            
            // Check audio levels to ensure we have meaningful audio
            let maxAmplitude = normalizedAudio.map { abs($0) }.max() ?? 0.0
            let avgAmplitude = normalizedAudio.map { abs($0) }.reduce(0, +) / Float(normalizedAudio.count)
            
            print("🎤 Transcribing audio: \(normalizedAudio.count) samples, duration: \(String(format: "%.2f", Double(normalizedAudio.count) / HermesConstants.sampleRate))s")
            print("🎤 Audio levels: max=\(String(format: "%.4f", maxAmplitude)), avg=\(String(format: "%.4f", avgAmplitude))")
            
            // Skip transcription if audio is too quiet (likely silence)
            // Lower threshold for natural microphone input levels
            guard avgAmplitude > 0.00001 else {
                print("🔇 Audio too quiet (avg: \(String(format: "%.6f", avgAmplitude))), skipping transcription")
                return
            }
            
            // Transcribe using WhisperKit with optimized settings
            let results = try await whisperKit.transcribe(audioArray: normalizedAudio)
            
            let latency = Date().timeIntervalSince(startTime)
            
            // Extract transcription text from first result
            let transcriptionText = results.first?.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            
            print("🔍 WhisperKit returned: '\(transcriptionText)' (latency: \(String(format: "%.2f", latency * 1000))ms)")
            print("🔍 Result length: \(transcriptionText.count), characters: \(Array(transcriptionText))")
            
            // Check if result is just dots or other meaningless patterns
            let onlyDots = transcriptionText.allSatisfy { $0 == "." }
            let onlyWhitespace = transcriptionText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
            
            // Skip empty results or common false positives
            guard !transcriptionText.isEmpty,
                  !onlyDots,
                  !onlyWhitespace,
                  transcriptionText.lowercased() != "thank you",
                  transcriptionText.lowercased() != "thanks",
                  transcriptionText.count > 2 else {
                print("🔄 Skipping invalid result: '\(transcriptionText)' (dots: \(onlyDots), empty: \(onlyWhitespace), length: \(transcriptionText.count))")
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
            
            print("✅ Transcription completed: '\(transcriptionText)'")
            
        } catch {
            print("❌ Transcription failed: \(error)")
            print("❌ Error details: \(String(describing: error))")
            
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
            
            // No fallback - openai_whisper-large-v3 is the only supported model
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