//
//  NotesView.swift
//  Hermes
//
//  Created by Claude Code on 7/24/25.
//

import SwiftUI
import Combine

/// Notes view with dictation-enabled text editor for testing WhisperKit integration
struct NotesView: View {
    @ObservedObject var dictationEngine: DictationEngine
    @State private var noteText: String = ""
    @State private var isRecording: Bool = false
    @State private var currentNote: Note = Note.emptyNote()
    @State private var recentTranscriptions: [TranscriptionResult] = []
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            notesHeader
            
            // Main content
            HStack(spacing: 24) {
                // Left side - Note editor
                noteEditor
                    .frame(maxWidth: .infinity)
                
                // Right side - Dictation panel
                dictationPanel
                    .frame(width: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            setupTranscriptionListener()
        }
    }
    
    // MARK: - Header
    
    private var notesHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Notes")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Test WhisperKit integration with real-time dictation")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Quick actions
            HStack(spacing: 12) {
                // Clear button
                Button("Clear Note") {
                    noteText = ""
                    currentNote = Note.emptyNote()
                }
                .secondaryButtonStyle()
                .disabled(noteText.isEmpty)
                
                // Save button
                Button("Save Note") {
                    saveCurrentNote()
                }
                .primaryButtonStyle()
                .disabled(noteText.isEmpty)
            }
        }
    }
    
    // MARK: - Note Editor
    
    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Note title
            VStack(alignment: .leading, spacing: 8) {
                Text("Note Title")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                HermesTextField(
                    text: $currentNote.title,
                    placeholder: "Enter note title..."
                )
            }
            
            // Note content editor
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Content")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(noteText.count) characters")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // Custom text editor with dictation integration
                DictationTextEditor(
                    text: $noteText,
                    dictationEngine: dictationEngine,
                    placeholder: "Start typing or press the record button to dictate...",
                    isRecording: $isRecording
                )
                .frame(minHeight: 400)
            }
            
            // Status bar
            if !recentTranscriptions.isEmpty {
                transcriptionStatusBar
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Dictation Panel
    
    private var dictationPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Panel header
            Text("Dictation Controls")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            // Recording controls
            dictationControls
            
            // Transcription service status
            transcriptionStatus
            
            // Recent transcriptions
            if !recentTranscriptions.isEmpty {
                recentTranscriptionsView
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
    
    private var dictationControls: some View {
        VStack(spacing: 16) {
            // Status indicator instead of button - use hotkey to dictate
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle")
                        .font(.system(size: 20))
                        .foregroundColor(isRecording ? .red : Color(hex: HermesConstants.primaryAccentColor))
                    
                    if dictationEngine.isProcessing && !isRecording {
                        Text("Processing...")
                            .font(.system(size: 14, weight: .medium))
                    } else {
                        Text(isRecording ? "Recording..." : "Use hotkey to dictate")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isRecording ? Color.red.opacity(0.1) : Color(hex: HermesConstants.primaryAccentColor).opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isRecording ? Color.red : Color(hex: HermesConstants.primaryAccentColor).opacity(0.5), lineWidth: 1)
                        )
                )
                
                // Hotkey hint
                if !isRecording {
                    Text("Hold your configured hotkey to start dictation")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Audio level indicator (if recording)
            if isRecording {
                audioLevelIndicator
            }
        }
    }
    
    private var audioLevelIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Audio Level")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Debug: Show actual audio level value
                Text(String(format: "%.2f", dictationEngine.audioManager.audioLevel))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            HStack(spacing: 4) {
                ForEach(0..<8) { index in
                    let threshold = Float(index) * 0.1
                    let isActive = dictationEngine.audioManager.audioLevel > threshold
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: HermesConstants.primaryAccentColor))
                        .frame(width: 6, height: CGFloat(8 + index * 3))
                        .opacity(isActive ? 1.0 : 0.3)
                        .animation(.easeInOut(duration: 0.1), value: isActive)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var transcriptionStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Status")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                statusRow("WhisperKit", 
                         dictationEngine.transcriptionService.isInitialized ? "Ready" : "Initializing",
                         dictationEngine.transcriptionService.isInitialized ? .green : .orange)
                
                statusRow("Audio Manager", 
                         isRecording ? "Recording" : "Ready",
                         isRecording ? Color(hex: HermesConstants.primaryAccentColor) : .green)
                
                if !dictationEngine.transcriptionService.currentModel.isEmpty {
                    statusRow("Model", 
                             dictationEngine.transcriptionService.currentModel,
                             .blue)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func statusRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var recentTranscriptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transcriptions")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(recentTranscriptions.prefix(5), id: \.id) { transcription in
                        transcriptionItem(transcription)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func transcriptionItem(_ transcription: TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(transcription.type == .partial ? "Partial" : "Final")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(transcription.type == .partial ? Color.orange : Color(hex: HermesConstants.primaryAccentColor))
                    .cornerRadius(4)
                
                Spacer()
                
                Text("\(String(format: "%.0f", transcription.latency * 1000))ms")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Text(transcription.text)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(6)
    }
    
    private var transcriptionStatusBar: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text("Last transcription: \(recentTranscriptions.last?.timestamp.formatted(date: .omitted, time: .shortened) ?? "None")")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if let lastTranscription = recentTranscriptions.last {
                Text("Latency: \(String(format: "%.0f", lastTranscription.latency * 1000))ms")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Methods
    
    private func setupTranscriptionListener() {
        // Listen to dictation engine state changes to sync recording status
        dictationEngine.$isActive
            .receive(on: DispatchQueue.main)
            .sink { isActive in
                // Update recording state based on dictation engine
                if dictationEngine.dictationContext == .local {
                    self.isRecording = isActive
                }
            }
            .store(in: &cancellables)
        
        // Listen to transcriptions when dictation context is local
        dictationEngine.transcriptionService.transcriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { transcriptionResult in
                // Only handle transcription if we're in local context (Notes view)
                if self.dictationEngine.dictationContext == .local {
                    self.handleTranscription(transcriptionResult)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleTranscription(_ result: HermesTranscriptionResult) {
        let transcriptionResult = TranscriptionResult(
            text: result.text,
            type: result.type == .partial ? .partial : .final,
            confidence: result.confidence,
            latency: result.latency,
            timestamp: result.timestamp
        )
        
        // Add to recent transcriptions
        recentTranscriptions.append(transcriptionResult)
        if recentTranscriptions.count > 10 {
            recentTranscriptions.removeFirst()
        }
        
        // Append to note text for final results
        if result.type == .final && !result.text.isEmpty {
            if !noteText.isEmpty && !noteText.hasSuffix(" ") {
                noteText += " "
            }
            noteText += result.text
            
            // Update note content
            currentNote.content = noteText
            currentNote.lastModified = Date()
        }
    }
    
    
    private func saveCurrentNote() {
        currentNote.content = noteText
        currentNote.lastModified = Date()
        
        // TODO: Implement note persistence
        print("Saving note: \(currentNote.title)")
    }
}

// MARK: - Supporting Types

struct TranscriptionResult: Identifiable {
    let id = UUID()
    let text: String
    let type: TranscriptionResultType
    let confidence: Double
    let latency: TimeInterval
    let timestamp: Date
}

struct Note: Identifiable {
    let id = UUID()
    var title: String
    var content: String
    var createdAt: Date
    var lastModified: Date
    
    static func emptyNote() -> Note {
        Note(
            title: "Untitled Note",
            content: "",
            createdAt: Date(),
            lastModified: Date()
        )
    }
}

// MARK: - Custom Text Editor

struct DictationTextEditor: View {
    @Binding var text: String
    @ObservedObject var dictationEngine: DictationEngine
    let placeholder: String
    @Binding var isRecording: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            
            // Text editor
            TextEditor(text: $text)
                .font(.system(size: 14))
                .padding(12)
                .scrollContentBackground(.hidden)
            
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
            
            // Dictation indicator
            if isRecording {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(1.2)
                                .animation(.easeInOut(duration: 0.5).repeatForever(), value: isRecording)
                            
                            Text("Dictating...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(16)
                }
            }
        }
    }
}

#Preview {
    NotesView(dictationEngine: DictationEngine.shared)
        .frame(width: 1000, height: 700)
}