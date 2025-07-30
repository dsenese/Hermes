//
//  MenuBarView.swift
//  Hermes
//
//  Created by Claude Code on 7/23/25.
//

import SwiftUI

/// Main menu bar interface following the Hermes design system
struct MenuBarView: View {
    @ObservedObject private var dictationEngine = DictationEngine.shared
    @State private var showingDictationPopup = false
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Menu bar content
            menuBarContent
                .padding()
            
            // Divider
            if showingSettings {
                Divider()
                    .opacity(0.3)
            }
            
            // Settings panel (expandable)
            if showingSettings {
                settingsPanel
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .background(menuBarBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showingDictationPopup) {
            DictationPopupView(dictationEngine: dictationEngine)
        }
    }
    
    // MARK: - Menu Bar Content
    
    private var menuBarContent: some View {
        HStack(spacing: 12) {
            // App icon and status
            appStatusSection
            
            Spacer()
            
            // Control buttons
            controlButtons
        }
    }
    
    private var appStatusSection: some View {
        HStack(spacing: 8) {
            // App icon
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundColor(dictationEngine.isActive ? Color(hex: HermesConstants.primaryAccentColor) : .secondary)
                .symbolEffect(.pulse, isActive: dictationEngine.isActive)
            
            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text("Hermes")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                statusText
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var statusText: some View {
        Group {
            if dictationEngine.isActive {
                if dictationEngine.isProcessing {
                    Text("Listening...")
                        .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
                } else {
                    Text("Ready")
                        .foregroundColor(.green)
                }
            } else {
                Text("Inactive")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 8) {
            // Open main app button
            Button(action: openMainApp) {
                Image(systemName: "macwindow")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open Dashboard")
            
            // Dictation toggle button
            Button(action: toggleDictation) {
                Image(systemName: dictationEngine.isActive ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                    .foregroundColor(dictationEngine.isActive ? .red : Color(hex: HermesConstants.primaryAccentColor))
            }
            .buttonStyle(.plain)
            .help(dictationEngine.isActive ? "Stop Dictation" : "Start Dictation")
            
            // Settings button
            Button(action: toggleSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
            
            // Quit button
            Button(action: quitApp) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit Hermes")
        }
    }
    
    // MARK: - Settings Panel
    
    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quick settings header
            HStack {
                Text("Quick Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Full Settings...") {
                    openFullSettings()
                }
                .buttonStyle(.plain)
                .foregroundColor(Color(hex: HermesConstants.primaryAccentColor))
            }
            
            // Quick toggles
            quickSettingsToggles
            
            // Usage stats
            usageStats
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private var quickSettingsToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Auto-format text", isOn: .constant(true))
            Toggle("Smart punctuation", isOn: .constant(true))
            Toggle("Code mode", isOn: .constant(false))
        }
        .toggleStyle(.switch)
        .font(.system(size: 13))
    }
    
    private var usageStats: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today: 1,247 characters")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("This month: 45,830 / 200,000")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Progress bar
            ProgressView(value: 45830, total: 200000)
                .progressViewStyle(.linear)
                .tint(Color(hex: HermesConstants.primaryAccentColor))
        }
    }
    
    // MARK: - Background
    
    private var menuBarBackground: some View {
        ZStack {
            // Adaptive background based on system appearance
            Color(NSColor.controlBackgroundColor)
                .opacity(0.95)
            
            // Subtle tinted overlay following design system
            Color(NSColor.controlAccentColor)
                .opacity(0.05)
        }
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Actions
    
    private func toggleDictation() {
        Task {
            await dictationEngine.toggleDictation()
            
            // Show dictation popup when starting
            if dictationEngine.isActive {
                showingDictationPopup = true
            }
        }
    }
    
    private func toggleSettings() {
        withAnimation(.easeInOut(duration: HermesConstants.animationDuration)) {
            showingSettings.toggle()
        }
    }
    
    private func openFullSettings() {
        // TODO: Open full settings window
        print("Opening full settings...")
    }
    
    private func openMainApp() {
        // Post notification to open main app
        NotificationCenter.default.post(name: .openMainApp, object: nil)
    }
    
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}


// MARK: - Preview

#Preview {
    MenuBarView()
        .frame(width: 300)
}