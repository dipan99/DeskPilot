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
    private let retriever: NotesHybridRetriever

    init(store: NotesStore = NotesStore(), configuration: NotesSearchConfiguration = .default) {
        self.store = store
        self.retriever = NotesHybridRetriever(configuration: configuration)
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

            let matches = retriever.search(query: query, notes: notes, maxResults: maxResults)
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
                    "snippet": match.snippet,
                    "content": match.snippet,
                    "updated_at": formatter.string(from: match.note.updatedAt),
                    "matched_terms": match.matchedTerms,
                    "lexical_score": match.lexicalScore,
                    "semantic_score": match.semanticScore,
                    "relevance_score": match.relevanceScore
                ] as [String: Any]
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

    private func parseArguments(_ arguments: String) -> ParsedArguments {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ParsedArguments(query: arguments, maxResults: 5)
        }

        let query = json["query"] as? String ?? arguments
        let maxResults = json["max_results"] as? Int ?? 5

        return ParsedArguments(query: query, maxResults: maxResults)
    }
}

struct NotesSearchConfiguration {
    let lexicalWeight: Double
    let semanticWeight: Double
    let minimumRelevanceScore: Double
    let snippetCharacterLimit: Int

    static let `default` = NotesSearchConfiguration(
        lexicalWeight: 0.6,
        semanticWeight: 0.4,
        minimumRelevanceScore: 0.08,
        snippetCharacterLimit: 800
    )
}

struct NotesSearchMatch {
    let note: DeskNote
    let snippet: String
    let matchedTerms: [String]
    let lexicalScore: Double
    let semanticScore: Double
    let relevanceScore: Double
}

struct NotesHybridRetriever {
    private let configuration: NotesSearchConfiguration
    private let lexicalScorer = NotesLexicalScorer()
    private let semanticScorer = NotesLocalSemanticScorer()

    init(configuration: NotesSearchConfiguration = .default) {
        self.configuration = configuration
    }

    func search(query: String, notes: [DeskNote], maxResults: Int) -> [NotesSearchMatch] {
        let queryTerms = NotesSearchText.terms(from: query)

        return notes.compactMap { note in
            let lexicalMatch = lexicalScorer.score(query: query, title: note.title, content: note.content)
            let semanticScore = semanticScorer.score(query: query, title: note.title, content: note.content)
            let relevanceScore = (
                configuration.lexicalWeight * lexicalMatch.score
            ) + (
                configuration.semanticWeight * semanticScore
            )

            guard relevanceScore >= configuration.minimumRelevanceScore else {
                return nil
            }

            return NotesSearchMatch(
                note: note,
                snippet: NotesSnippetBuilder.snippet(
                    from: note.content,
                    queryTerms: queryTerms,
                    characterLimit: configuration.snippetCharacterLimit
                ),
                matchedTerms: lexicalMatch.matchedTerms,
                lexicalScore: lexicalMatch.score,
                semanticScore: semanticScore,
                relevanceScore: relevanceScore
            )
        }
        .sorted { lhs, rhs in
            if lhs.relevanceScore == rhs.relevanceScore {
                return lhs.note.updatedAt > rhs.note.updatedAt
            }

            return lhs.relevanceScore > rhs.relevanceScore
        }
        .prefix(maxResults)
        .map { $0 }
    }
}

struct NotesLexicalMatch {
    let score: Double
    let matchedTerms: [String]
}

struct NotesLexicalScorer {
    func score(query: String, title: String, content: String) -> NotesLexicalMatch {
        let queryTerms = NotesSearchText.terms(from: query)
        guard !queryTerms.isEmpty else {
            return NotesLexicalMatch(score: 0, matchedTerms: [])
        }

        let normalizedQuery = NotesSearchText.normalized(query)
        let normalizedText = NotesSearchText.normalized(title + " " + content)
        let titleTerms = Set(NotesSearchText.terms(from: title))
        let contentTerms = Set(NotesSearchText.terms(from: content))
        let allTerms = titleTerms.union(contentTerms)

        var rawScore = 0.0
        var matchedTerms: [String] = []

        if normalizedText.contains(normalizedQuery) {
            rawScore += Double(queryTerms.count) * 2.5
        }

        for term in queryTerms where allTerms.contains(term) {
            matchedTerms.append(term)
            rawScore += titleTerms.contains(term) ? 1.5 : 1.0
        }

        let maximumUsefulScore = Double(queryTerms.count) * 4.0
        let normalizedScore = min(rawScore / maximumUsefulScore, 1.0)

        return NotesLexicalMatch(
            score: normalizedScore,
            matchedTerms: Array(Set(matchedTerms)).sorted()
        )
    }
}

struct NotesLocalSemanticScorer {
    func score(query: String, title: String, content: String) -> Double {
        let queryFeatures = NotesSearchText.features(from: query)
        let noteFeatures = NotesSearchText.features(from: title + " " + content)

        guard !queryFeatures.isEmpty, !noteFeatures.isEmpty else {
            return 0
        }

        let queryFeatureSet = Set(queryFeatures)
        let noteFeatureSet = Set(noteFeatures)
        let overlapCount = queryFeatureSet.intersection(noteFeatureSet).count
        let denominator = sqrt(Double(queryFeatureSet.count) * Double(noteFeatureSet.count))

        guard denominator > 0 else {
            return 0
        }

        return min(Double(overlapCount) / denominator, 1.0)
    }
}

enum NotesSnippetBuilder {
    static func snippet(from content: String, queryTerms: [String], characterLimit: Int) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > characterLimit else {
            return trimmed
        }

        let normalizedContent = NotesSearchText.normalized(trimmed)
        let firstMatchIndex = queryTerms
            .compactMap { normalizedContent.range(of: $0)?.lowerBound }
            .min()

        guard let firstMatchIndex else {
            return String(trimmed.prefix(characterLimit)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }

        let approximateContentIndex = String.Index(
            utf16Offset: normalizedContent.distance(from: normalizedContent.startIndex, to: firstMatchIndex),
            in: trimmed
        )
        let halfLimit = max(characterLimit / 2, 1)
        let start = trimmed.index(
            approximateContentIndex,
            offsetBy: -halfLimit,
            limitedBy: trimmed.startIndex
        ) ?? trimmed.startIndex
        let end = trimmed.index(
            start,
            offsetBy: characterLimit,
            limitedBy: trimmed.endIndex
        ) ?? trimmed.endIndex
        let snippet = trimmed[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)

        let prefix = start == trimmed.startIndex ? "" : "..."
        let suffix = end == trimmed.endIndex ? "" : "..."
        return prefix + snippet + suffix
    }
}

enum NotesSearchText {
    private nonisolated static let ignoredTerms: Set<String> = [
        "a", "an", "and", "are", "as", "at", "do", "for", "from", "had", "has", "have",
        "i", "in", "is", "it", "me", "my", "of", "on", "or", "that", "the", "to", "was",
        "were", "what", "when", "where", "which", "who", "with"
    ]

    nonisolated static func normalized(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    nonisolated static func terms(from text: String) -> [String] {
        normalized(text).split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 2 && !ignoredTerms.contains($0) }
    }

    nonisolated static func features(from text: String) -> [String] {
        let terms = terms(from: text)
        let stems = terms.map(stem)
        let bigrams = zip(stems, stems.dropFirst()).map { "\($0)_\($1)" }
        let characterTrigrams = stems.flatMap { trigrams(from: $0) }

        return stems + bigrams + characterTrigrams
    }

    private nonisolated static func stem(_ term: String) -> String {
        var stemmed = term
        for suffix in ["ing", "ed", "es", "s"] where stemmed.count > suffix.count + 2 && stemmed.hasSuffix(suffix) {
            stemmed.removeLast(suffix.count)
            return stemmed
        }

        return stemmed
    }

    private nonisolated static func trigrams(from term: String) -> [String] {
        guard term.count >= 3 else {
            return [term]
        }

        return term.indices.dropLast(2).map { index in
            let end = term.index(index, offsetBy: 3)
            return String(term[index..<end])
        }
    }
}
