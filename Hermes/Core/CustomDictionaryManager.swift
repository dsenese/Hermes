//
//  CustomDictionaryManager.swift
//  Hermes
//
//  Created by Claude Code on 8/7/25.
//

import Foundation
import Combine

/// Model for custom dictionary entries
struct DictionaryEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var word: String
    var correctSpelling: String
    var category: DictionaryCategory
    var dateAdded: Date
    var usage: String? // Context or example usage
    
    init(word: String, correctSpelling: String, category: DictionaryCategory = .general, usage: String? = nil) {
        self.id = UUID()
        self.word = word.lowercased()
        self.correctSpelling = correctSpelling
        self.category = category
        self.dateAdded = Date()
        self.usage = usage
    }
}

/// Categories for dictionary entries
enum DictionaryCategory: String, CaseIterable, Codable {
    case general = "General"
    case names = "Names"
    case technical = "Technical"
    case medical = "Medical"
    case business = "Business"
    case custom = "Custom"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .general: return "text.book.closed"
        case .names: return "person.circle"
        case .technical: return "gearshape"
        case .medical: return "cross.case"
        case .business: return "briefcase"
        case .custom: return "star"
        }
    }
}

/// Manages custom dictionary entries for spell correction and AI formatting
@MainActor
class CustomDictionaryManager: ObservableObject {
    // MARK: - Singleton
    static let shared = CustomDictionaryManager()
    
    // MARK: - Published Properties
    @Published private(set) var entries: [DictionaryEntry] = []
    @Published private(set) var isLoading = false
    @Published var searchText = ""
    @Published private(set) var selectedCategory: DictionaryCategory?
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let storageKey = "HermesCustomDictionary"
    private var cancellables = Set<AnyCancellable>()
    
    // Fast lookup dictionary for performance
    private var lookupDictionary: [String: String] = [:]
    
    private init() {
        loadEntries()
        setupSearchAndFiltering()
    }
    
    // MARK: - Public Methods
    
    /// Add a new dictionary entry
    func addEntry(word: String, correctSpelling: String, category: DictionaryCategory = .general, usage: String? = nil) {
        let entry = DictionaryEntry(
            word: word,
            correctSpelling: correctSpelling,
            category: category,
            usage: usage
        )
        
        // Check if entry already exists
        if !entries.contains(where: { $0.word == entry.word }) {
            entries.append(entry)
            rebuildLookupDictionary()
            saveEntries()
            print("📖 Added dictionary entry: '\(word)' -> '\(correctSpelling)'")
        } else {
            print("⚠️ Dictionary entry for '\(word)' already exists")
        }
    }
    
    /// Update an existing dictionary entry
    func updateEntry(_ entry: DictionaryEntry, word: String, correctSpelling: String, category: DictionaryCategory, usage: String?) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].word = word.lowercased()
            entries[index].correctSpelling = correctSpelling
            entries[index].category = category
            entries[index].usage = usage
            
            rebuildLookupDictionary()
            saveEntries()
            print("📖 Updated dictionary entry: '\(word)' -> '\(correctSpelling)'")
        }
    }
    
    /// Remove a dictionary entry
    func removeEntry(_ entry: DictionaryEntry) {
        entries.removeAll { $0.id == entry.id }
        rebuildLookupDictionary()
        saveEntries()
        print("📖 Removed dictionary entry: '\(entry.word)'")
    }
    
    /// Remove multiple entries
    func removeEntries(_ entriesToRemove: [DictionaryEntry]) {
        let idsToRemove = Set(entriesToRemove.map { $0.id })
        entries.removeAll { idsToRemove.contains($0.id) }
        rebuildLookupDictionary()
        saveEntries()
        print("📖 Removed \(entriesToRemove.count) dictionary entries")
    }
    
    /// Get correction for a word if it exists in the dictionary
    func getCorrection(for word: String) -> String? {
        return lookupDictionary[word.lowercased()]
    }
    
    /// Apply dictionary corrections to text
    func applyCorrections(to text: String) -> String {
        _ = text
        
        // Split text into words while preserving punctuation and spacing
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var correctedWords: [String] = []
        
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            
            if let correction = getCorrection(for: cleanWord) {
                // Preserve original capitalization pattern
                let correctedWord = preserveCapitalization(original: cleanWord, correction: correction)
                // Replace the clean word with correction, preserving punctuation
                let correctedWithPunctuation = word.replacingOccurrences(of: cleanWord, with: correctedWord)
                correctedWords.append(correctedWithPunctuation)
                print("📖 Applied correction: '\(cleanWord)' -> '\(correctedWord)'")
            } else {
                correctedWords.append(word)
            }
        }
        
        return correctedWords.joined(separator: " ")
    }
    
    /// Import entries from JSON data
    func importEntries(from data: Data) throws {
        let decoder = JSONDecoder()
        let importedEntries = try decoder.decode([DictionaryEntry].self, from: data)
        
        // Add only new entries (avoid duplicates)
        let existingWords = Set(entries.map { $0.word })
        let newEntries = importedEntries.filter { !existingWords.contains($0.word) }
        
        entries.append(contentsOf: newEntries)
        rebuildLookupDictionary()
        saveEntries()
        
        print("📖 Imported \(newEntries.count) new dictionary entries")
    }
    
    /// Export entries to JSON data
    func exportEntries() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try encoder.encode(entries)
    }
    
    /// Clear all entries
    func clearAllEntries() {
        entries.removeAll()
        lookupDictionary.removeAll()
        saveEntries()
        print("📖 Cleared all dictionary entries")
    }
    
    /// Get filtered entries based on current search and category
    var filteredEntries: [DictionaryEntry] {
        var filtered = entries
        
        // Apply category filter
        if let selectedCategory = selectedCategory {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { entry in
                entry.word.localizedCaseInsensitiveContains(searchText) ||
                entry.correctSpelling.localizedCaseInsensitiveContains(searchText) ||
                (entry.usage?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Sort by date added (newest first)
        return filtered.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    /// Update search text
    func updateSearchText(_ text: String) {
        searchText = text
    }
    
    /// Update selected category
    func updateSelectedCategory(_ category: DictionaryCategory?) {
        selectedCategory = category
    }
    
    // MARK: - Private Methods
    
    private func loadEntries() {
        isLoading = true
        
        if let data = userDefaults.data(forKey: storageKey) {
            do {
                let decoder = JSONDecoder()
                entries = try decoder.decode([DictionaryEntry].self, from: data)
                rebuildLookupDictionary()
                print("📖 Loaded \(entries.count) dictionary entries")
            } catch {
                print("❌ Failed to load dictionary entries: \(error)")
                entries = []
            }
        } else {
            // Load default entries if no custom dictionary exists
            loadDefaultEntries()
        }
        
        isLoading = false
    }
    
    private func saveEntries() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entries)
            userDefaults.set(data, forKey: storageKey)
            print("📖 Saved \(entries.count) dictionary entries")
        } catch {
            print("❌ Failed to save dictionary entries: \(error)")
        }
    }
    
    private func rebuildLookupDictionary() {
        lookupDictionary = Dictionary(uniqueKeysWithValues: entries.map { ($0.word, $0.correctSpelling) })
    }
    
    private func preserveCapitalization(original: String, correction: String) -> String {
        guard !original.isEmpty && !correction.isEmpty else { return correction }
        
        if original.first?.isUppercase == true {
            return correction.capitalized
        }
        
        return correction.lowercased()
    }
    
    private func setupSearchAndFiltering() {
        // Could add debounced search if needed
        // For now, filtering is reactive through computed property
    }
    
    private func loadDefaultEntries() {
        // Add some common default entries
        let defaultEntries = [
            DictionaryEntry(word: "hermes", correctSpelling: "Hermes", category: .names),
            DictionaryEntry(word: "ai", correctSpelling: "AI", category: .technical),
            DictionaryEntry(word: "gpt", correctSpelling: "GPT", category: .technical),
            DictionaryEntry(word: "api", correctSpelling: "API", category: .technical),
        ]
        
        entries = defaultEntries
        rebuildLookupDictionary()
        saveEntries()
        print("📖 Loaded \(defaultEntries.count) default dictionary entries")
    }
}

// MARK: - Extensions

extension CustomDictionaryManager {
    /// Get statistics about the dictionary
    var statistics: DictionaryStatistics {
        let categoryCounts = Dictionary(grouping: entries, by: { $0.category })
            .mapValues { $0.count }
        
        return DictionaryStatistics(
            totalEntries: entries.count,
            categoryCounts: categoryCounts
        )
    }
}

/// Statistics about the custom dictionary
struct DictionaryStatistics {
    let totalEntries: Int
    let categoryCounts: [DictionaryCategory: Int]
    
    var mostUsedCategory: DictionaryCategory? {
        categoryCounts.max(by: { $0.value < $1.value })?.key
    }
}