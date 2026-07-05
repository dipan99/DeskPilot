//
//  FilesTool.swift
//  DeskPilot
//

import Foundation
import os

private let logger = Logger(subsystem: "com.dipanbag.DeskPilot", category: "FilesTool")

struct FilesTool: Tool {
    let name = "search_files"
    let displayName = "File Search"
    let description = "Search for files and folders by name on the user's Mac. Can search the whole system or within a specific directory."
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "query": [
                "type": "string",
                "description": "The file or folder name to search for (e.g. 'resume', 'notes.pdf', 'project')"
            ],
            "search_path": [
                "type": "string",
                "description": "Optional directory path to limit the search (e.g. '/Users/dipanbag/Documents'). If omitted, searches the entire system."
            ]
        ],
        "required": ["query"]
    ]

    func execute(arguments: String) async -> ToolResult {
        let args = parseArguments(arguments)
        let query = args.query
        let searchPath = args.searchPath

        logger.debug("Searching for '\(query)' in \(searchPath ?? "entire system")")

        let results = await SpotlightSearch.search(query: query, searchPath: searchPath)

        logger.debug("Found \(results.count) result(s)")

        if results.isEmpty {
            return ToolResult(toolName: displayName, output: "No files found matching '\(query)'.")
        }

        if let data = try? JSONSerialization.data(withJSONObject: results),
           let json = String(data: data, encoding: .utf8) {
            return ToolResult(toolName: displayName, output: json)
        }

        return ToolResult(toolName: displayName, output: "Found \(results.count) files but failed to format results.")
    }

    private struct ParsedArgs {
        let query: String
        let searchPath: String?
    }

    private func parseArguments(_ arguments: String) -> ParsedArgs {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return ParsedArgs(query: arguments, searchPath: nil)
        }

        return ParsedArgs(
            query: json["query"] ?? arguments,
            searchPath: json["search_path"]
        )
    }
}

// MARK: - Spotlight Search (MainActor-isolated)

@MainActor
private final class SpotlightSearch {
    static func search(query: String, searchPath: String?) async -> [[String: String]] {
        let metadataQuery = NSMetadataQuery()
        metadataQuery.predicate = NSPredicate(format: "kMDItemFSName CONTAINS[cd] %@", query)

        if let path = searchPath {
            metadataQuery.searchScopes = [path]
        } else {
            metadataQuery.searchScopes = [
                NSMetadataQueryUserHomeScope,
                NSMetadataQueryLocalComputerScope
            ]
        }

        metadataQuery.start()

        // Wait for the query to finish using the async notification stream
        for await notification in NotificationCenter.default.notifications(named: .NSMetadataQueryDidFinishGathering) {
            if (notification.object as AnyObject) === metadataQuery {
                break
            }
        }

        metadataQuery.stop()

        // Collect results
        let maxResults = 20
        let count = min(metadataQuery.resultCount, maxResults)
        var files: [[String: String]] = []

        for i in 0..<count {
            if let item = metadataQuery.result(at: i) as? NSMetadataItem {
                let name = item.value(forAttribute: kMDItemFSName as String) as? String ?? "Unknown"
                let path = item.value(forAttribute: kMDItemPath as String) as? String ?? "Unknown"
                files.append(["name": name, "path": path])
            }
        }

        return files
    }
}

