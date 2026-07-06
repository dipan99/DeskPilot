//
//  NotesTool.swift
//  DeskPilot
//

import Foundation
import os

private let notesLogger = Logger(subsystem: "com.dipanbag.DeskPilot", category: "NotesTool")

struct NotesTool: Tool {
    let name = "search_notes"
    let displayName = "Notes"
    let description = "Search the user's saved DeskPilot notes by title and content. Use this when the user asks about information they may have written in notes, such as names, phone numbers, meeting notes, ideas, or saved details."
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "query": [
                "type": "string",
                "description": "The information to search for in notes, such as a person, topic, phone number, or phrase."
            ],
            "max_results": [
                "type": "integer",
                "description": "Optional maximum number of matching notes to return. Defaults to 5."
            ]
        ],
        "required": ["query"]
    ]

    private let store: NotesStore

    init(store: NotesStore = NotesStore()) {
        self.store = store
    }

    func execute(arguments: String) async -> ToolResult {
        let parsedArguments = parseArguments(arguments)
        let query = parsedArguments.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxResults = min(max(parsedArguments.maxResults, 1), 10)

        notesLogger.debug("Searching notes for query: \(query)")

        guard !query.isEmpty else {
            return ToolResult(toolName: displayName, output: "No notes query was provided.")
        }

        do {
            let notes = try await store.loadNotes()
            guard !notes.isEmpty else {
                return ToolResult(toolName: displayName, output: "No notes have been saved yet.")
            }

            let matches = rankedMatches(for: query, in: notes, maxResults: maxResults)
            notesLogger.debug("Found \(matches.count) matching note(s)")

            guard !matches.isEmpty else {
                return ToolResult(toolName: displayName, output: "No saved notes matched '\(query)'.")
            }

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            let result = matches.map { match in
                [
                    "title": match.note.title,
                    "content": trimmedContent(match.note.content),
                    "updated_at": formatter.string(from: match.note.updatedAt),
                    "relevance_score": String(match.score)
                ]
            }

            if let data = try? JSONSerialization.data(withJSONObject: result),
               let json = String(data: data, encoding: .utf8) {
                return ToolResult(toolName: displayName, output: json)
            }

            return ToolResult(toolName: displayName, output: "Found matching notes but failed to format results.")
        } catch {
            notesLogger.error("Failed to search notes: \(error.localizedDescription)")
            return ToolResult(toolName: displayName, output: "Failed to search notes: \(error.localizedDescription)")
        }
    }

    private struct ParsedArguments {
        let query: String
        let maxResults: Int
    }

    private struct NoteMatch {
        let note: DeskNote
        let score: Int
    }

    private func parseArguments(_ arguments: String) -> ParsedArguments {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ParsedArguments(query: arguments, maxResults: 5)
        }

        let query = json["query"] as? String ?? arguments
        let maxResults = json["max_results"] as? Int ?? 5

        return ParsedArguments(query: query, maxResults: maxResults)
    }

    private func rankedMatches(for query: String, in notes: [DeskNote], maxResults: Int) -> [NoteMatch] {
        let normalizedQuery = query.normalizedForNotesSearch
        let queryTerms = searchTerms(in: normalizedQuery)

        return notes.compactMap { note in
            let searchableTitle = note.title.normalizedForNotesSearch
            let searchableContent = note.content.normalizedForNotesSearch
            let searchableText = searchableTitle + " " + searchableContent

            var score = 0

            if searchableText.contains(normalizedQuery) {
                score += 20
            }

            for term in queryTerms where searchableText.contains(term) {
                score += searchableTitle.contains(term) ? 4 : 2
            }

            guard score > 0 else {
                return nil
            }

            return NoteMatch(note: note, score: score)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.note.updatedAt > rhs.note.updatedAt
            }

            return lhs.score > rhs.score
        }
        .prefix(maxResults)
        .map { $0 }
    }

    private func searchTerms(in text: String) -> [String] {
        let ignoredTerms: Set<String> = [
            "a", "an", "and", "are", "as", "at", "do", "for", "from", "had", "has", "have",
            "i", "in", "is", "it", "me", "my", "of", "on", "or", "that", "the", "to", "was",
            "were", "what", "when", "where", "which", "who", "with"
        ]

        return text.split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 2 && !ignoredTerms.contains($0) }
    }

    private func trimmedContent(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 2_000 else {
            return trimmed
        }

        return String(trimmed.prefix(2_000)) + "..."
    }
}

private extension String {
    var normalizedForNotesSearch: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
