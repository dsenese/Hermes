//
//  DictionaryView.swift
//  Hermes
//
//  Created by Claude Code on 8/7/25.
//

import SwiftUI

/// Simple dictionary view for custom spelling corrections
struct DictionaryView: View {
    @StateObject private var dictionaryManager = CustomDictionaryManager.shared
    @State private var showingAddEntry = false
    @State private var newCorrection = ""
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Dictionary")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Add words for spelling correction")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Content
            if dictionaryManager.entries.isEmpty {
                emptyStateView
            } else {
                entriesListView
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showingAddEntry) {
            addEntrySheet
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("No dictionary entries yet")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Add words that need spelling correction during dictation")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Add your first word") {
                    showingAddEntry = true
                }
                .primaryButtonStyle()
            }
            
            Spacer()
        }
    }
    
    // MARK: - Entries List
    
    private var entriesListView: some View {
        VStack(spacing: 16) {
            // Add button
            HStack {
                Spacer()
                Button("Add new") {
                    showingAddEntry = true
                }
                .primaryButtonStyle()
            }
            
            // Entries
            LazyVStack(spacing: 1) {
                ForEach(dictionaryManager.entries) { entry in
                    entryRow(entry)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private func entryRow(_ entry: DictionaryEntry) -> some View {
        HStack {
            Text(entry.correctSpelling)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button {
                dictionaryManager.removeEntry(entry)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Add Entry Sheet
    
    private var addEntrySheet: some View {
        VStack(spacing: 24) {
            Text("Add Dictionary Entry")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Correct Spelling")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                TextField("Enter the correct spelling", text: $newCorrection)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 16))
                
                Text("AI will match this with similar-sounding words")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    showingAddEntry = false
                    newCorrection = ""
                }
                .secondaryButtonStyle()
                
                Button("Add") {
                    addEntry()
                }
                .primaryButtonStyle()
                .disabled(newCorrection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(32)
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func addEntry() {
        let trimmed = newCorrection.trimmingCharacters(in: .whitespacesAndNewlines)
        
        dictionaryManager.addEntry(
            word: trimmed.lowercased(),
            correctSpelling: trimmed,
            category: .general,
            usage: nil
        )
        
        showingAddEntry = false
        newCorrection = ""
    }
}

#Preview {
    DictionaryView()
        .frame(width: 800, height: 600)
}