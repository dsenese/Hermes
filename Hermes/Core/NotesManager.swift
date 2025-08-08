//
//  NotesManager.swift
//  Hermes
//
//  Created by GPT-5 on 8/7/25.
//

import Foundation

@MainActor
final class NotesManager: ObservableObject {
    static let shared = NotesManager()

    @Published private(set) var notes: [Note] = []
    @Published var searchQuery: String = ""
    @Published var sortOrder: NotesSortOrder = .modifiedDesc

    private let fileManager = FileManager.default
    private let notesFileURL: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let notesDir = appSupport.appendingPathComponent("Hermes/Notes", isDirectory: true)
        try? fileManager.createDirectory(at: notesDir, withIntermediateDirectories: true)
        notesFileURL = notesDir.appendingPathComponent("notes.json")
        load()
    }

    func load() {
        do {
            if fileManager.fileExists(atPath: notesFileURL.path) {
                let data = try Data(contentsOf: notesFileURL)
                let decoded = try JSONDecoder().decode([Note].self, from: data)
                notes = decoded
            } else {
                notes = []
            }
        } catch {
            print("⚠️ Failed to load notes: \(error)")
            notes = []
        }
    }

    func save(noteContent: String, noteId: UUID? = nil) {
        let trimmed = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let id = noteId, let idx = notes.firstIndex(where: { $0.id == id }) {
            notes[idx].content = trimmed
            notes[idx].lastModified = Date()
        } else {
            let new = Note(content: trimmed)
            notes.insert(new, at: 0)
        }

        persist()
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        persist()
    }

    func clearAll() {
        notes.removeAll()
        persist()
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(notes)
            try data.write(to: notesFileURL)
        } catch {
            print("❌ Failed to save notes: \(error)")
        }
    }

    // MARK: - Query
    var filteredNotes: [Note] {
        let base: [Note]
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            base = notes
        } else {
            let q = searchQuery.lowercased()
            base = notes.filter { $0.content.lowercased().contains(q) }
        }
        return base.sorted(by: sortOrder.sorter)
    }
}

// MARK: - Model

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    let createdAt: Date
    var lastModified: Date

    init(id: UUID = UUID(), content: String, createdAt: Date = Date(), lastModified: Date = Date()) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.lastModified = lastModified
    }

    var previewLine: String {
        let first = content.split(separator: "\n").first.map(String.init) ?? content
        return String(first.prefix(60))
    }
}

enum NotesSortOrder: String, CaseIterable {
    case modifiedDesc = "Modified (newest)"
    case modifiedAsc = "Modified (oldest)"
    case createdDesc = "Created (newest)"
    case createdAsc = "Created (oldest)"

    var sorter: (Note, Note) -> Bool {
        switch self {
        case .modifiedDesc: return { $0.lastModified > $1.lastModified }
        case .modifiedAsc:  return { $0.lastModified < $1.lastModified }
        case .createdDesc:  return { $0.createdAt > $1.createdAt }
        case .createdAsc:   return { $0.createdAt < $1.createdAt }
        }
    }
}


