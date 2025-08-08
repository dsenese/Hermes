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
    @StateObject private var notesManager = NotesManager.shared
    @State private var noteText: String = ""
    @State private var isRecording: Bool = false
    @State private var currentNote: Note = Note(content: "")
    @State private var recentTranscriptions: [TranscriptionResult] = []
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Minimal header
                Text("For quick thoughts you want to come back to")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)

                // Full-width notes editor + actions
                noteEditor
                    .frame(maxWidth: .infinity)

                // History list with search and ordering
                notesHistory
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            setupTranscriptionListener()
        }
    }

    // MARK: - Header

    private var notesHeader: some View { EmptyView() }

    // MARK: - Note Editor

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Full-width custom text area
            DictationTextEditor(
                text: $noteText,
                dictationEngine: dictationEngine,
                placeholder: "Take a quick note with your voice",
                isRecording: $isRecording
            )
            .frame(minHeight: 240)

            // Actions
            HStack(spacing: 12) {
                Button("Save") {
                    notesManager.save(noteContent: noteText, noteId: currentNote.id)
                    noteText = ""
                    currentNote = Note(content: "")
                }
                .primaryButtonStyle()
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Clear") {
                    noteText = ""
                    currentNote = Note(content: "")
                }
                .secondaryButtonStyle()

                Spacer()

                Text("\(noteText.count) chars")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            #if DEBUG
            // Dev-only status bar
            if !recentTranscriptions.isEmpty {
                transcriptionStatusBar
            }
            #endif
        }
    }

    // MARK: - Dictation Panel

    #if DEBUG
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
    #endif

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

    #if DEBUG
    private var recentTranscriptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recents")
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
    #endif

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

    // MARK: - Notes History
    private var notesHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("History")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                HermesDropdown(
                    title: nil,
                    selection: $notesManager.sortOrder,
                    options: NotesSortOrder.allCases.map { ($0, $0.rawValue) },
                    placeholder: "Order"
                )
                .frame(width: 220)
            }

            // Search field
            HermesUnderlinedTextField(
                text: $notesManager.searchQuery,
                placeholder: "Search notes",
                leadingSystemImage: "magnifyingglass"
            )

            if notesManager.filteredNotes.isEmpty {
                Text("No notes found")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(notesManager.filteredNotes) { note in
                        Button(action: {
                            currentNote = note
                            noteText = note.content
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.previewLine)
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(note.lastModified.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: { notesManager.delete(note) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
        notesManager.save(noteContent: noteText, noteId: currentNote.id)
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

// Legacy Note model removed; using NotesManager.Note

// MARK: - Custom Text Editor

struct DictationTextEditor: View {
    @Binding var text: String
    @ObservedObject var dictationEngine: DictationEngine
    let placeholder: String
    @Binding var isRecording: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hermes-styled text area
            HermesTextArea(
                text: $text,
                placeholder: placeholder,
                minHeight: 360
            )

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
