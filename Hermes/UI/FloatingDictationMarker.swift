//
//  FloatingDictationMarker.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI
import AppKit

/// Floating dictation marker that hovers over all applications
struct FloatingDictationMarker: View {
    @ObservedObject var dictationEngine: DictationEngine
    @State private var isHovered = false
    @State private var showingClickPrompt = false
    @State private var waveformAmplitude: CGFloat = 0.0
    @State private var animationTimer: Timer?
    
    private let inactiveSize = CGSize(width: 50, height: 8)
    private let activeSize = CGSize(width: 80, height: 30)
    private let expandedSize = CGSize(width: 120, height: 50)
    
    var body: some View {
        ZStack {
            if currentState == .inactive {
                inactiveMarker
            } else if currentState == .hovered || showingClickPrompt {
                hoveredMarker
            } else {
                activeMarker
            }
        }
        .frame(width: currentSize.width, height: currentSize.height)
        .background(markerBackground)
        .cornerRadius(currentSize.height / 2) // Pill shape
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .opacity(currentOpacity)
        .animation(.easeInOut(duration: 0.2), value: currentState)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering && currentState == .inactive {
                showingClickPrompt = true
            } else if !hovering {
                showingClickPrompt = false
            }
        }
        .onTapGesture {
            startDictation()
        }
        .onAppear {
            startWaveformAnimation()
        }
        .onDisappear {
            stopWaveformAnimation()
        }
    }
    
    // MARK: - State Management
    
    private enum MarkerState {
        case inactive
        case hovered
        case active
    }
    
    private var currentState: MarkerState {
        if dictationEngine.isActive {
            return .active
        } else if isHovered || showingClickPrompt {
            return .hovered
        } else {
            return .inactive
        }
    }
    
    private var currentSize: CGSize {
        switch currentState {
        case .inactive:
            return inactiveSize
        case .hovered:
            return showingClickPrompt ? expandedSize : activeSize
        case .active:
            return activeSize
        }
    }
    
    private var currentOpacity: Double {
        switch currentState {
        case .inactive:
            return 0.8
        case .hovered, .active:
            return 1.0
        }
    }
    
    // MARK: - Marker States
    
    private var inactiveMarker: some View {
        // Very minimal pill - just a subtle presence
        Rectangle()
            .fill(Color.clear)
    }
    
    private var hoveredMarker: some View {
        VStack(spacing: 8) {
            if showingClickPrompt {
                // Top pill with click prompt
                Text("Click to start dictating")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#1C1C1E"))
                    .cornerRadius(12)
            }
            
            // Bottom pill with dotted line or waveform
            HStack(spacing: 0) {
                if dictationEngine.isActive {
                    waveformView
                } else {
                    dottedLineView
                }
            }
            .frame(width: activeSize.width, height: activeSize.height)
        }
    }
    
    private var activeMarker: some View {
        // Simple waveform animation during dictation
        waveformView
            .frame(width: activeSize.width, height: activeSize.height)
    }
    
    // MARK: - Components
    
    private var markerBackground: some View {
        Color(hex: "#1C1C1E")
            .opacity(0.95)
    }
    
    private var dottedLineView: some View {
        HStack(spacing: 3) {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2, height: 2)
            }
        }
    }
    
    private var waveformView: some View {
        HStack(spacing: 2) {
            ForEach(0..<12, id: \.self) { index in
                waveformBar(for: index)
            }
        }
    }
    
    private func waveformBar(for index: Int) -> some View {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 20
        let animationDelay = Double(index) * 0.1
        
        // Ensure height is always positive by using abs() and adding a minimum
        let waveHeight = abs(sin(Date().timeIntervalSince1970 * 3 + animationDelay))
        let finalHeight = max(2, baseHeight + (waveformAmplitude * maxHeight * waveHeight))
        
        return Rectangle()
            .fill(Color.white)
            .frame(width: 2, height: finalHeight)
            .cornerRadius(1)
    }
    
    // MARK: - Actions
    
    private func startDictation() {
        Task {
            await dictationEngine.startDictation()
            showingClickPrompt = false
        }
    }
    
    private func startWaveformAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.1)) {
                    if dictationEngine.isActive {
                        waveformAmplitude = CGFloat.random(in: 0.3...1.0)
                    } else {
                        waveformAmplitude = CGFloat.random(in: 0.1...0.3)
                    }
                }
            }
        }
    }
    
    private func stopWaveformAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// MARK: - Floating Window Controller

class FloatingDictationController: NSWindowController {
    private var floatingWindow: NSFloatingPanel?
    private var dictationEngine: DictationEngine
    
    init(dictationEngine: DictationEngine) {
        self.dictationEngine = dictationEngine
        super.init(window: nil)
        setupFloatingWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupFloatingWindow() {
        // Create floating panel
        floatingWindow = NSFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        guard let window = floatingWindow else { return }
        
        // Configure window properties
        window.level = .floating // Stays above all other windows
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // Position at bottom center of screen
        positionWindowAtBottomCenter()
        
        // Set up SwiftUI content
        let contentView = NSHostingView(rootView: FloatingDictationMarker(dictationEngine: dictationEngine))
        window.contentView = contentView
        
        self.window = window
    }
    
    private func positionWindowAtBottomCenter() {
        guard let window = floatingWindow,
              let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        
        let x = screenFrame.midX - (windowSize.width / 2)
        let y = screenFrame.minY + 100 // 100pt from bottom
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func show() {
        floatingWindow?.orderFrontRegardless()
        floatingWindow?.makeKeyAndOrderFront(nil)
    }
    
    func hide() {
        floatingWindow?.orderOut(nil)
    }
}

// MARK: - Custom NSPanel for Floating Behavior

class NSFloatingPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Ensure the panel can receive mouse events
        self.isMovableByWindowBackground = false
        self.isReleasedWhenClosed = false
    }
}


// MARK: - Preview

#Preview {
    FloatingDictationMarker(dictationEngine: DictationEngine.shared)
        .frame(width: 200, height: 100)
        .background(Color.gray.opacity(0.3))
}