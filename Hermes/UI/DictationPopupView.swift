//
//  DictationPopupView.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI

/// Floating dictation popup that shows real-time transcription
struct DictationPopupView: View {
    @ObservedObject var dictationEngine: DictationEngine
    @StateObject private var audioManager = AudioManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var isVisible = false
    @State private var shouldPulse = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            popupHeader
            
            // Main transcription area
            transcriptionArea
            
            // Audio visualization and status
            audioVisualization
        }
        .frame(width: HermesConstants.popupWidth, height: HermesConstants.popupHeight)
        .background(popupBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 8)
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
        .onChange(of: dictationEngine.isActive) { _, isActive in
            if !isActive {
                dismissPopup()
            }
        }
    }
    
    // MARK: - Header
    
    private var popupHeader: some View {
        HStack {
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(dictationEngine.isActive ? Color(hex: HermesConstants.primaryAccentColor) : .gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(shouldPulse ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: shouldPulse)
                
                Text(dictationStatusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Control buttons
            HStack(spacing: 8) {
                // Minimize button
                Button(action: dismissPopup) {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Minimize")
                
                // Stop dictation button
                Button(action: stopDictation) {
                    Image(systemName: "stop.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Stop Dictation")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.05))
    }
    
    private var dictationStatusText: String {
        if !dictationEngine.isActive {
            return "Inactive"
        } else if dictationEngine.isProcessing {
            return "Listening..."
        } else {
            return "Ready"
        }
    }
    
    // MARK: - Transcription Area
    
    private var transcriptionArea: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                // Final transcription
                if !dictationEngine.currentTranscription.isEmpty {
                    Text(dictationEngine.currentTranscription)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .transition(.opacity.combined(with: .scale))
                }
                
                // Partial transcription (grayed out)
                if !dictationEngine.partialTranscription.isEmpty {
                    Text(dictationEngine.partialTranscription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .transition(.opacity)
                }
                
                // Placeholder when empty
                if dictationEngine.currentTranscription.isEmpty && dictationEngine.partialTranscription.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.title)
                            .foregroundColor(.secondary)
                            .symbolEffect(.pulse, isActive: dictationEngine.isActive)
                        
                        Text(dictationEngine.isActive ? "Start speaking..." : "Press microphone to begin")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Audio Visualization
    
    private var audioVisualization: some View {
        VStack(spacing: 8) {
            // Audio level visualization
            audioLevelVisualization
            
            // Error message (if any)
            if let errorMessage = dictationEngine.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            // Hotkey hint
            hotkeyHint
        }
        .padding(.bottom, 12)
    }
    
    private var audioLevelVisualization: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: audioManager.audioLevel)
            }
        }
        .frame(height: 20)
        .padding(.horizontal, 16)
    }
    
    private func barColor(for index: Int) -> Color {
        let normalizedLevel = Double(audioManager.audioLevel * 20)
        if Double(index) < normalizedLevel {
            return Color(hex: HermesConstants.primaryAccentColor)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let normalizedLevel = Double(audioManager.audioLevel * 20)
        let barLevel = max(0, normalizedLevel - Double(index))
        return CGFloat(4 + barLevel * 16)
    }
    
    private var hotkeyHint: some View {
        Text("Press \(HermesConstants.defaultHotkey) to toggle")
            .font(.caption2)
            .foregroundColor(Color.secondary.opacity(0.7))
    }
    
    // MARK: - Background
    
    private var popupBackground: some View {
        ZStack {
            // Main background (adaptive)
            Color(NSColor.windowBackgroundColor)
            
            // Subtle accent tint
            Color(hex: HermesConstants.primaryAccentColor)
                .opacity(0.02)
            
            // Material effect
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
    }
    
    // MARK: - Actions
    
    private func dismissPopup() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
    
    private func stopDictation() {
        Task {
            await dictationEngine.stopDictation()
            dismissPopup()
        }
    }
    
    // MARK: - Lifecycle
    
    private func startPulseAnimation() {
        shouldPulse = dictationEngine.isActive
    }
}

// MARK: - Popup Window Management

/// Window controller for the floating dictation popup
class DictationPopupWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: HermesConstants.popupWidth,
                height: HermesConstants.popupHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Center the window on screen
        window.center()
        
        self.init(window: window)
    }
    
    func show(with dictationEngine: DictationEngine) {
        let hostingView = NSHostingView(rootView: DictationPopupView(dictationEngine: dictationEngine))
        window?.contentView = hostingView
        window?.makeKeyAndOrderFront(nil)
        
        // Animate in
        window?.animator().alphaValue = 1.0
    }
    
    func hide() {
        window?.animator().alphaValue = 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.window?.orderOut(nil)
        }
    }
}

// MARK: - Preview

#Preview {
    DictationPopupView(dictationEngine: DictationEngine())
}