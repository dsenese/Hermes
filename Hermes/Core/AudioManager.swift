//
//  AudioManager.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import Foundation
import AVFoundation
import Combine

/// Manages audio capture and processing for dictation
@MainActor
class AudioManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isRecording = false
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var isVoiceActive = false
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioBuffer: AVAudioPCMBuffer?
    private var voiceActivityDetector: VoiceActivityDetector?
    
    // Audio format configuration (16kHz mono as specified)
    private let sampleRate: Double = HermesConstants.sampleRate
    private let channels: AVAudioChannelCount = AVAudioChannelCount(HermesConstants.channels)
    private let chunkDuration: TimeInterval = HermesConstants.chunkDuration
    
    // Audio processing
    private var audioDataBuffer: [Float] = []
    private let bufferSize: Int = 1024
    
    // Publishers for audio data
    private let audioDataSubject = PassthroughSubject<Data, Never>()
    var audioDataPublisher: AnyPublisher<Data, Never> {
        audioDataSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init() {
        setupAudioEngine()
        voiceActivityDetector = VoiceActivityDetector()
    }
    
    // MARK: - Public Methods
    
    /// Requests microphone permission and starts audio capture
    func startRecording() async throws {
        guard !isRecording else { return }
        
        // Request microphone permission explicitly
        print("🎤 Requesting microphone permission...")
        let permission = await AVAudioApplication.requestRecordPermission()
        
        if permission {
            print("✅ Microphone permission granted")
        } else {
            print("❌ Microphone permission denied")
            throw AudioManagerError.microphonePermissionDenied
        }
        
        // Always create fresh audio engine to avoid session conflicts
        setupAudioEngine()
        
        try await setupAndStartRecording()
    }
    
    /// Stops audio capture
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop the engine first
        audioEngine?.stop()
        
        // Remove tap if it exists
        if let inputNode = inputNode {
            inputNode.removeTap(onBus: 0)
        }
        
        isRecording = false
        isVoiceActive = false
        audioLevel = 0.0
        
        print("🎤 Audio recording stopped")
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine() {
        // Always create a fresh engine to avoid -10877 errors
        if audioEngine != nil {
            audioEngine?.stop()
        }
        
        audioEngine = AVAudioEngine()
        print("🎤 Created new audio engine")
        
        // Set up the default audio input device (non-intrusive)  
        configureInputDevice()
        
        inputNode = audioEngine?.inputNode
        
        print("🎤 Audio engine setup completed")
        if let inputNode = inputNode {
            print("🎤 Input node format: \(inputNode.inputFormat(forBus: 0))")
        }
    }
    
    private func configureInputDevice() {
        // On macOS, respect the user's current audio device configuration
        // Don't change or interfere with existing audio routing
        
        print("🎤 Preserving current audio device configuration")
        print("🎤 Using whatever input device is currently active")
        
        // Note: We intentionally don't modify audio device settings to avoid
        // disconnecting headphones or changing the user's audio setup
    }
    
    private func resetAudioEngine() {
        // Only clean up existing engine, don't destroy it unless necessary
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            if let input = inputNode {
                // Safely remove tap with error handling
                do {
                    input.removeTap(onBus: 0)
                    print("🔧 Audio tap removed successfully")
                } catch {
                    print("⚠️ Error removing audio tap: \(error)")
                }
            }
        }
        
        // Don't set audioEngine to nil - reuse the same engine to avoid device disruption
        inputNode = nil
        audioDataBuffer.removeAll()
        print("🔧 Audio engine cleaned up (engine preserved)")
    }
    
    private func setupAndStartRecording() async throws {
        guard let audioEngine = audioEngine else {
            throw AudioManagerError.audioEngineSetupFailed
        }
        
        // Get the audio input node (microphone)
        let inputNode = audioEngine.inputNode
        
        // Get the native hardware format of the microphone
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        print("🎤 Microphone hardware format: \(inputFormat)")
        print("🎤 Sample rate: \(inputFormat.sampleRate) Hz")
        print("🎤 Channels: \(inputFormat.channelCount)")
        
        // Verify we have a valid input format
        guard inputFormat.channelCount > 0 else {
            print("❌ No microphone input detected!")
            throw AudioManagerError.audioFormatSetupFailed
        }
        
        // Create our desired recording format (16kHz mono for WhisperKit)
        guard let recordingFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channels
        ) else {
            throw AudioManagerError.audioFormatSetupFailed
        }
        
        print("🎤 Target recording format: \(recordingFormat)")
        
        // Remove any existing tap
        inputNode.removeTap(onBus: 0)
        
        // Create a converter if needed
        var converter: AVAudioConverter?
        if inputFormat.sampleRate != recordingFormat.sampleRate {
            converter = AVAudioConverter(from: inputFormat, to: recordingFormat)
            print("🔧 Created audio converter from \(inputFormat.sampleRate)Hz to \(recordingFormat.sampleRate)Hz")
        }
        
        // Install tap on the microphone input with a larger buffer for better capture
        let bufferSize = AVAudioFrameCount(4096) // Larger buffer for better capture
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Process the audio buffer
            Task { @MainActor in
                if let converter = converter {
                    // Convert to our target format
                    await self.processConvertedAudioBuffer(buffer, converter: converter, targetFormat: recordingFormat)
                } else {
                    // Direct processing if formats match
                    await self.processAudioBuffer(buffer, format: recordingFormat)
                }
            }
        }
        
        // Start the audio engine without prepare() to avoid session disruption
        // prepare() can sometimes change audio routing, so we skip it
        try audioEngine.start()
        
        isRecording = true
        self.inputNode = inputNode
        
        print("✅ Audio engine started - capturing from microphone")
        print("🎤 Tap installed on bus 0 with buffer size: \(bufferSize)")
    }
    
    private func processConvertedAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) async {
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * (targetFormat.sampleRate / buffer.format.sampleRate))
        ) else { return }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("❌ Audio conversion error: \(error)")
            return
        }
        
        await processAudioBuffer(convertedBuffer, format: targetFormat)
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) async {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let audioData = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        
        // Calculate audio levels without artificial amplification
        let rms = sqrt(audioData.map { $0 * $0 }.reduce(0, +) / Float(frameLength))
        let maxAmplitude = audioData.map { abs($0) }.max() ?? 0.0
        let avgAmplitude = audioData.map { abs($0) }.reduce(0, +) / Float(frameLength)
        
        // Update audio level for UI feedback (scale up for better visualization)
        await MainActor.run {
            audioLevel = max(rms * 10.0, maxAmplitude * 5.0, avgAmplitude * 20.0) // Scale for UI only
        }
        
        // Debug logging for all audio levels to diagnose input
        print("🎤 Audio buffer: frames=\(frameLength), max=\(String(format: "%.6f", maxAmplitude)), avg=\(String(format: "%.6f", avgAmplitude)), rms=\(String(format: "%.6f", rms)), ui_level=\(String(format: "%.2f", audioLevel))")
        
        // Voice Activity Detection using raw data
        let voiceDetected = await voiceActivityDetector?.detectVoice(in: audioData) ?? false
        isVoiceActive = voiceDetected
        
        // Use raw data for accumulation (no artificial gain)
        audioDataBuffer.append(contentsOf: audioData)
        
        // Send periodic chunks for accumulation (2 second chunks for smoother flow)
        let samplesPerChunk = Int(sampleRate * 2.0) // 2 second chunks
        if audioDataBuffer.count >= samplesPerChunk {
            let chunk = Array(audioDataBuffer.prefix(samplesPerChunk))
            audioDataBuffer.removeFirst(samplesPerChunk)
            
            // Convert float array to Data
            let audioData = chunk.withUnsafeBufferPointer { buffer in
                Data(buffer: buffer)
            }
            
            // Emit audio data for accumulation (not immediate transcription)
            audioDataSubject.send(audioData)
        }
    }
    
    deinit {
        // Capture engine and inputNode references to avoid self capture
        let engine = self.audioEngine
        let inputNode = self.inputNode
        
        Task { @MainActor in
            engine?.stop()
            inputNode?.removeTap(onBus: 0)
        }
    }
}

// MARK: - Voice Activity Detector
actor VoiceActivityDetector {
    private let energyThreshold: Float = 0.01
    private let silenceThreshold: TimeInterval = 0.5
    private var lastVoiceTime: Date = Date()
    
    func detectVoice(in audioData: [Float]) async -> Bool {
        // Simple energy-based VAD (will be enhanced with WebRTC VAD later)
        let energy = audioData.map { $0 * $0 }.reduce(0, +) / Float(audioData.count)
        let hasVoice = energy > energyThreshold
        
        if hasVoice {
            lastVoiceTime = Date()
        }
        
        // Return true if we detected voice recently
        return Date().timeIntervalSince(lastVoiceTime) < silenceThreshold
    }
}

// MARK: - Error Types
enum AudioManagerError: LocalizedError {
    case microphonePermissionDenied
    case audioEngineSetupFailed
    case audioFormatSetupFailed
    case recordingFailed
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required for dictation"
        case .audioEngineSetupFailed:
            return "Failed to setup audio engine"
        case .audioFormatSetupFailed:
            return "Failed to setup audio format"
        case .recordingFailed:
            return "Failed to start recording"
        }
    }
}