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
    private let processingQueue = DispatchQueue(label: "com.hermes.audioProcessing", qos: .userInitiated)
    private let maxAudioBufferDuration: TimeInterval = 30.0
    private var lastAudioLogTime = Date(timeIntervalSince1970: 0)

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
    @MainActor
    func startRecording() async throws {
        guard !isRecording else { return }

        // Check microphone permission (should already be granted from app launch)
        print("🎤 Checking microphone permission...")
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        switch permissionStatus {
        case .authorized:
            print("✅ Microphone permission granted")
        case .denied, .restricted:
            print("❌ Microphone permission denied or restricted")
            throw AudioManagerError.microphonePermissionDenied
        case .notDetermined:
            print("🎤 Microphone permission undetermined, requesting now...")
            let permission = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }

            if !permission {
                print("❌ Microphone permission denied by user")
                throw AudioManagerError.microphonePermissionDenied
            }
            print("✅ Microphone permission granted by user")
        @unknown default:
            print("⚠️ Unknown microphone permission status")
            throw AudioManagerError.microphonePermissionDenied
        }

        // Configure audio session to be non-intrusive
        try configureAudioSession()

        // Clear any residual audio buffer before starting new session
        audioDataBuffer.removeAll()

        // Only setup engine if not already initialized
        if audioEngine == nil {
            setupAudioEngine()
        }

        try await setupAndStartRecording()
    }

    /// Stops audio capture
    @MainActor
    func stopRecording() {
        guard isRecording else { return }

        // Stop the engine first
        audioEngine?.stop()

        // Remove tap if it exists
        if let inputNode = inputNode {
            inputNode.removeTap(onBus: 0)
        }

        // CRITICAL: Send any remaining buffered audio before clearing
        if !audioDataBuffer.isEmpty {
            print("🎤 Sending final \(audioDataBuffer.count) samples (\(String(format: "%.2f", Double(audioDataBuffer.count) / sampleRate))s) to transcription")

            // Convert remaining samples to Data and send to transcription service
            let remainingAudio = audioDataBuffer.withUnsafeBufferPointer { buffer in
                Data(buffer: buffer)
            }
            audioDataSubject.send(remainingAudio)
        }

        // Now clear the buffer to prevent carryover to next session
        audioDataBuffer.removeAll()

        isRecording = false
        isVoiceActive = false
        audioLevel = 0.0

        print("🎤 Audio recording stopped, all audio sent to transcription")
    }

    // MARK: - Private Methods

    private func setupAudioEngine() {
        // Only create new engine if needed
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
            print("🎤 Created new audio engine")
        } else {
            print("🎤 Reusing existing audio engine")
        }

        inputNode = audioEngine?.inputNode

        print("🎤 Audio engine setup completed")
        if let inputNode = inputNode {
            print("🎤 Input node format: \(inputNode.inputFormat(forBus: 0))")
        }
    }

    private func configureAudioSession() throws {
        // On macOS, we don't need to configure audio sessions like iOS
        // The system handles audio routing automatically
        // We just need to ensure we don't interfere with existing audio device setup
        print("✅ Audio session configured for macOS (non-intrusive mode)")
    }

    private func resetAudioEngine() {
        // Only clean up existing engine, don't destroy it unless necessary
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            if let input = inputNode {
                // Safely remove tap with error handling
                input.removeTap(onBus: 0)
                print("🔧 Audio tap removed successfully")
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
        if inputFormat.sampleRate != recordingFormat.sampleRate || inputFormat.channelCount != recordingFormat.channelCount {
            converter = AVAudioConverter(from: inputFormat, to: recordingFormat)
            print("🔧 Created audio converter from \(inputFormat.sampleRate)Hz/\(inputFormat.channelCount)ch to \(recordingFormat.sampleRate)Hz/\(recordingFormat.channelCount)ch")
        }

        // Install tap on the microphone input with a larger buffer for better capture
        let bufferSize = AVAudioFrameCount(4096) // Larger buffer for better capture

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Copy samples immediately inside the tap to avoid lifetime issues
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            let copiedAudio = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

            // Process copied samples on a background queue (keep tap lightweight)
            self.processingQueue.async { [weak self] in
                guard let self = self else { return }

                // Optionally convert to target format on background queue
                if let converter = converter {
                    guard let tempInputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(frameLength)) else { return }
                    tempInputBuffer.frameLength = AVAudioFrameCount(frameLength)
                    if let dst = tempInputBuffer.floatChannelData?[0] {
                        dst.assign(from: copiedAudio, count: frameLength)
                    }

                    guard let convertedBuffer = AVAudioPCMBuffer(
                        pcmFormat: recordingFormat,
                        frameCapacity: AVAudioFrameCount(Double(frameLength) * (recordingFormat.sampleRate / inputFormat.sampleRate))
                    ) else { return }

                    var error: NSError?
                    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                        outStatus.pointee = .haveData
                        return tempInputBuffer
                    }
                    converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                    if error != nil {
                        return
                    }

                    // Use converted samples
                    guard let convertedChannel = convertedBuffer.floatChannelData?[0] else { return }
                    let convertedFrameLen = Int(convertedBuffer.frameLength)
                    let samples = Array(UnsafeBufferPointer(start: convertedChannel, count: convertedFrameLen))
                    self.handleAudioSamples(samples)
                } else {
                    // Use original samples (already target format)
                    self.handleAudioSamples(copiedAudio)
                }
            }
        }

        // Prepare and start the audio engine with error handling
        do {
            if !audioEngine.isRunning {
                audioEngine.prepare()
                try audioEngine.start()
                print("✅ Audio engine started successfully")
            } else {
                print("🎤 Audio engine already running")
            }
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            throw AudioManagerError.recordingFailed
        }

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
        // Deprecated path: keep for compatibility but route through safe handler
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let audioData = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        handleAudioSamples(audioData)
    }

    private func handleAudioSamples(_ samples: [Float]) {
        let frameLength = samples.count
        guard frameLength > 0 else { return }

        // Calculate audio levels
        let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(frameLength))
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0.0
        let avgAmplitude = samples.map { abs($0) }.reduce(0, +) / Float(frameLength)

        // Update UI level
        Task { @MainActor in
            self.audioLevel = max(rms * 10.0, maxAmplitude * 5.0, avgAmplitude * 20.0)
        }

        // Voice Activity Detection (async actor)
        Task {
            let voiceDetected = await self.voiceActivityDetector?.detectVoice(in: samples) ?? false
            await MainActor.run {
                self.isVoiceActive = voiceDetected
            }
        }

        // Accumulate and cap buffer
        audioDataBuffer.append(contentsOf: samples)
        let maxSamples = Int(maxAudioBufferDuration * sampleRate)
        if audioDataBuffer.count > maxSamples {
            let overflow = audioDataBuffer.count - maxSamples
            audioDataBuffer.removeFirst(overflow)
        }

        // Send new chunk
        let newAudioData = samples.withUnsafeBufferPointer { Data(buffer: $0) }
        audioDataSubject.send(newAudioData)

        // Throttled logging
        let now = Date()
        if now.timeIntervalSince(lastAudioLogTime) >= 0.5 {
            lastAudioLogTime = now
            let uiLevelSnapshot = audioLevel
            print("🎤 Audio buffer: frames=\(frameLength), max=\(String(format: "%.6f", maxAmplitude)), avg=\(String(format: "%.6f", avgAmplitude)), rms=\(String(format: "%.6f", rms)), ui_level=\(String(format: "%.2f", uiLevelSnapshot))")
        }

        // Periodic accumulation log
        let totalSamples = audioDataBuffer.count
        if totalSamples % Int(sampleRate * 2.0) == 0 { // approx every 2s
            let duration = Double(totalSamples) / sampleRate
            let window = audioDataBuffer.suffix(Int(sampleRate * 2.0))
            let maxLevel = window.map { abs($0) }.max() ?? 0.0
            let avgLevel = window.reduce(0, +) / Float(max(window.count, 1))
            print("🎤 Accumulating audio: \(totalSamples) total samples (\(String(format: "%.1f", duration))s)")
            print("🎤 Recent 2s levels: max=\(String(format: "%.6f", maxLevel)), avg=\(String(format: "%.6f", avgLevel))")
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
