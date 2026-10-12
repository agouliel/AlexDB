import SwiftUI

struct SongsView: View {
    @EnvironmentObject var api: APIClient
    @State private var showNew = false
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            PagedList<Song, SongCell>(path: "/songs/songs_data/") { SongCell(song: $0, onChange: { refreshID = UUID() }) }
                .id(refreshID)
                .navigationTitle("Songs")
                .toolbar {
                    if api.isLoggedIn {
                        Button { showNew = true } label: { Image(systemName: "plus") }
                    }
                }
                .sheet(isPresented: $showNew) {
                    SongFormView(song: nil) { refreshID = UUID() }
                }
        }
    }
}

struct SongCell: View {
    let song: Song
    let onChange: () -> Void
    @EnvironmentObject var api: APIClient

    var body: some View {
        NavigationLink {
            SongDetailView(song: song, onChange: onChange)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title ?? "—").font(.headline)
                Text([song.artist, song.album].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

struct SongDetailView: View {
    let song: Song
    let onChange: () -> Void
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var error: String?

    var body: some View {
        Form {
            row("Title", song.title)
            row("Artist", song.artist)
            row("Album", song.album)
            row("Composer", song.composer)
            row("Comment", song.comment)
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle(song.title ?? "Song")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if api.isLoggedIn {
                Menu {
                    Button("Edit") { showEdit = true }
                    Button("Delete", role: .destructive) { confirmDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showEdit) {
            SongFormView(song: song) { onChange(); dismiss() }
        }
        .confirmationDialog("Delete this song?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    do { try await api.deleteSong(id: song.sid); onChange(); dismiss() }
                    catch { self.error = error.localizedDescription }
                }
            }
        }
    }

    @ViewBuilder private func row(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(label) { Text(value).multilineTextAlignment(.trailing) }
        }
    }
}

struct SongFormView: View {
    let song: Song?
    let onSaved: () -> Void
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    @State private var draft = SongDraft()
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $draft.title)
                TextField("Artist", text: $draft.artist)
                TextField("Album", text: $draft.album)
                TextField("Composer", text: $draft.composer)
                TextField("Comment", text: $draft.comment, axis: .vertical)
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(song == nil ? "New Song" : "Edit Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(saving || draft.title.isEmpty)
                }
            }
            .onAppear { if let song { draft = SongDraft(song) } }
        }
    }

    private func save() {
        saving = true
        Task {
            defer { saving = false }
            do {
                try await api.saveSong(draft, id: song?.sid)
                dismiss()
                onSaved()
            } catch { self.error = error.localizedDescription }
        }
    }
}
