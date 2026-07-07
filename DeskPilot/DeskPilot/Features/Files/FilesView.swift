//
//  FilesView.swift
//  DeskPilot
//

import AppKit
import Foundation
import SwiftUI

struct FilesView: View {
    @State private var state: FilesViewState = .idle

    private let loader = RecentFileLoader()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            content
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await loadRecentItems()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Files")
                    .font(.largeTitle)
                    .bold()
                    .accessibilityIdentifier("Files_title")

                Text("Recently accessed files and folders from Spotlight.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await loadRecentItems()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(state.isLoading)
            .accessibilityIdentifier("filesRefreshButton")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            ProgressView("Loading recent files...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("filesLoading")
        case .loading:
            ProgressView("Loading recent files...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("filesLoading")
        case .empty:
            FilesStateView(
                systemImage: "folder",
                title: "No Recent Items Found",
                message: "DeskPilot could not find recently accessed files or folders from Spotlight metadata."
            )
            .accessibilityIdentifier("filesEmptyState")
        case .failed(let message):
            FilesStateView(
                systemImage: "exclamationmark.triangle",
                title: "Could Not Load Files",
                message: message
            )
            .accessibilityIdentifier("filesErrorState")
        case .loaded(let items):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            revealInFinder(item.url)
                        } label: {
                            RecentFileRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 24)
            }
            .accessibilityIdentifier("recentFilesList")
        }
    }

    @MainActor
    private func loadRecentItems() async {
        guard !state.isLoading else {
            return
        }

        state = .loading

        do {
            let items = try await loader.loadRecentItems(limit: 10)
            state = items.isEmpty ? .empty : .loaded(items)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

private enum FilesViewState {
    case idle
    case loading
    case empty
    case failed(String)
    case loaded([RecentFileItem])

    var isLoading: Bool {
        if case .loading = self {
            return true
        }

        return false
    }
}

private struct RecentFileRow: View {
    let item: RecentFileItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.isFolder ? "folder" : "doc")
                .font(.title3)
                .foregroundStyle(item.isFolder ? .blue : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(2)

                Text(item.url.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("Last opened \(item.lastUsedDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.forward.app")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.14))
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("recentFileRow")
    }
}

private struct FilesStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RecentFileItem: Identifiable, Hashable {
    let url: URL
    let name: String
    let lastUsedDate: Date
    let isFolder: Bool

    var id: String { url.path }
}

private enum RecentFileLoaderError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        switch self {
        case .timedOut:
            return "Spotlight did not return recent file metadata in time."
        }
    }
}

@MainActor
private final class RecentFileLoader {
    func loadRecentItems(limit: Int) async throws -> [RecentFileItem] {
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(
            format: "%K > %@",
            kMDItemLastUsedDate as String,
            Date.distantPast as NSDate
        )
        query.searchScopes = [
            NSMetadataQueryUserHomeScope,
            NSMetadataQueryLocalComputerScope
        ]

        query.start()

        do {
            try await waitForQueryToFinish(query)
        } catch {
            query.stop()
            throw error
        }

        query.stop()

        return collectRecentItems(from: query, limit: limit)
    }

    private func waitForQueryToFinish(_ query: NSMetadataQuery) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                for await notification in NotificationCenter.default.notifications(named: .NSMetadataQueryDidFinishGathering) {
                    if (notification.object as AnyObject) === query {
                        return
                    }
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                throw RecentFileLoaderError.timedOut
            }

            try await group.next()
            group.cancelAll()
        }
    }

    private func collectRecentItems(from query: NSMetadataQuery, limit: Int) -> [RecentFileItem] {
        var seenPaths = Set<String>()
        var items: [RecentFileItem] = []

        for index in 0..<query.resultCount {
            guard let metadataItem = query.result(at: index) as? NSMetadataItem,
                  let path = metadataItem.value(forAttribute: kMDItemPath as String) as? String,
                  let lastUsedDate = metadataItem.value(forAttribute: kMDItemLastUsedDate as String) as? Date else {
                continue
            }

            guard seenPaths.insert(path).inserted else {
                continue
            }

            let url = URL(fileURLWithPath: path)
            items.append(RecentFileItem(
                url: url,
                name: metadataItem.value(forAttribute: kMDItemFSName as String) as? String ?? url.lastPathComponent,
                lastUsedDate: lastUsedDate,
                isFolder: isFolder(metadataItem: metadataItem, url: url)
            ))
        }

        return items
            .sorted { $0.lastUsedDate > $1.lastUsedDate }
            .prefix(limit)
            .map { $0 }
    }

    private func isFolder(metadataItem: NSMetadataItem, url: URL) -> Bool {
        if let contentTypes = metadataItem.value(forAttribute: kMDItemContentTypeTree as String) as? [String] {
            return contentTypes.contains("public.folder")
        }

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
}

#Preview {
    FilesView()
}
