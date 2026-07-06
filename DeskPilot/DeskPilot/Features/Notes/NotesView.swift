//
//  NotesView.swift
//  DeskPilot
//

import Foundation
import SwiftUI

struct DeskNote: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct NotesView: View {
    @State private var notes: [DeskNote] = []
    @State private var isShowingEditor = false
    @State private var editingNoteID: DeskNote.ID?
    @State private var draftTitle = ""
    @State private var draftContent = ""
    @State private var errorMessage: String?

    private let store = NotesStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    addNoteCard

                    ForEach(notes) { note in
                        Button {
                            editNote(note)
                        } label: {
                            NoteCard(note: note)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("noteCard")
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await loadNotes()
        }
        .sheet(isPresented: $isShowingEditor) {
            NoteEditorView(
                editorTitle: editingNoteID == nil ? "New Note" : "Edit Note",
                title: $draftTitle,
                content: $draftContent,
                onCancel: dismissEditor,
                onSave: saveDraft
            )
            .frame(minWidth: 520, minHeight: 420)
        }
        .alert("Notes Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.largeTitle)
                .bold()
                .accessibilityIdentifier("Notes_title")

            Text("Capture quick notes and keep them available locally.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var addNoteCard: some View {
        Button {
            startNewNote()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 34))

                Text("New Note")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        }
        .accessibilityIdentifier("newNoteButton")
    }

    private func loadNotes() async {
        do {
            notes = try await store.loadNotes()
        } catch {
            errorMessage = "Could not load notes: \(error.localizedDescription)"
        }
    }

    private func startNewNote() {
        editingNoteID = nil
        draftTitle = ""
        draftContent = ""
        isShowingEditor = true
    }

    private func editNote(_ note: DeskNote) {
        editingNoteID = note.id
        draftTitle = note.title
        draftContent = note.content
        isShowingEditor = true
    }

    private func saveDraft() {
        let content = draftContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = NotesTitleFormatter.title(from: draftTitle, content: content)

        guard !title.isEmpty || !content.isEmpty else {
            return
        }

        if let editingNoteID, let index = notes.firstIndex(where: { $0.id == editingNoteID }) {
            notes[index].title = title
            notes[index].content = content
            notes[index].updatedAt = Date()
        } else {
            let note = DeskNote(title: title, content: content)
            notes.insert(note, at: 0)
        }

        dismissEditor()

        Task {
            await persistNotes()
        }
    }

    private func persistNotes() async {
        do {
            try await store.saveNotes(notes)
        } catch {
            errorMessage = "Could not save notes: \(error.localizedDescription)"
        }
    }

    private func dismissEditor() {
        isShowingEditor = false
        editingNoteID = nil
        draftTitle = ""
        draftContent = ""
    }
}

struct NoteCard: View {
    let note: DeskNote

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.title)
                .font(.headline)
                .lineLimit(2)
                .accessibilityIdentifier("noteTitle")

            Text(note.content.isEmpty ? "No content" : note.content)
                .font(.body)
                .foregroundStyle(note.content.isEmpty ? .secondary : .primary)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Text(note.updatedAt, format: .dateTime.month().day().year().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.14))
        }
    }
}

struct NoteEditorView: View {
    let editorTitle: String

    @Binding var title: String
    @Binding var content: String

    let onCancel: () -> Void
    let onSave: () -> Void

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editorTitle)
                .font(.title2)
                .bold()

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("noteTitleField")

            TextEditor(text: $content)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.16))
                }
                .accessibilityIdentifier("noteContentEditor")

            HStack {
                Spacer()

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .accessibilityIdentifier("noteSaveButton")
            }
        }
        .padding(24)
    }
}

enum NotesTitleFormatter {
    static func title(from draftTitle: String, content: String) -> String {
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        guard let firstLine = content
            .components(separatedBy: .newlines)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            return "Untitled Note"
        }

        if firstLine.count <= 48 {
            return firstLine
        }

        return String(firstLine.prefix(48)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

struct NotesStore {
    private let fileManager: FileManager
    private let notesURL: URL

    init(fileManager: FileManager = .default, notesURL: URL? = nil) {
        self.fileManager = fileManager

        if let notesURL {
            self.notesURL = notesURL
        } else {
            let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.notesURL = supportDirectory
                .appendingPathComponent("DeskPilot", isDirectory: true)
                .appendingPathComponent("notes.json")
        }
    }

    func loadNotes() async throws -> [DeskNote] {
        guard fileManager.fileExists(atPath: notesURL.path) else {
            return []
        }

        let data = try Data(contentsOf: notesURL)
        return try JSONDecoder().decode([DeskNote].self, from: data)
    }

    func saveNotes(_ notes: [DeskNote]) async throws {
        let directoryURL = notesURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(notes)
        try data.write(to: notesURL, options: .atomic)
    }
}

#Preview {
    NotesView()
}
