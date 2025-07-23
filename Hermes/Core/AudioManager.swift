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
        // Request microphone permission
        let permission = await AVAudioApplication.requestRecordPermission()
        guard permission else {
            throw AudioManagerError.microphonePermissionDenied
        }
        
        try await setupAndStartRecording()
    }
    
    /// Stops audio capture
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        isRecording = false
        isVoiceActive = false
        audioLevel = 0.0
        
        print("🎤 Audio recording stopped")
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
    }
    
    private func setupAndStartRecording() async throws {
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            throw AudioManagerError.audioEngineSetupFailed
        }
        
        // Note: AVAudioSession is not available on macOS
        // Audio configuration is handled directly through AVAudioEngine
        
        // Set up the desired audio format (16kHz mono)
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let recordingFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channels
        )
        
        guard let recordingFormat = recordingFormat else {
            throw AudioManagerError.audioFormatSetupFailed
        }
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: inputFormat) { [weak self] buffer, time in
            Task { @MainActor in
                await self?.processAudioBuffer(buffer, format: recordingFormat)
            }
        }
        
        // Start the audio engine
        try audioEngine.start()
        isRecording = true
        
        print("🎤 Audio recording started - Format: \(recordingFormat)")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) async {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let audioData = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        
        // Update audio level for UI feedback
        let rms = sqrt(audioData.map { $0 * $0 }.reduce(0, +) / Float(frameLength))
        audioLevel = rms
        
        // Voice Activity Detection
        let voiceDetected = await voiceActivityDetector?.detectVoice(in: audioData) ?? false
        isVoiceActive = voiceDetected
        
        // Convert to the desired format and accumulate data
        audioDataBuffer.append(contentsOf: audioData)
        
        // Send chunks of audio data when we have enough (5 second chunks as specified)
        let samplesPerChunk = Int(sampleRate * chunkDuration)
        if audioDataBuffer.count >= samplesPerChunk {
            let chunk = Array(audioDataBuffer.prefix(samplesPerChunk))
            audioDataBuffer.removeFirst(samplesPerChunk)
            
            // Convert float array to Data
            let audioData = chunk.withUnsafeBufferPointer { buffer in
                Data(buffer: buffer)
            }
            
            // Emit audio data for transcription
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