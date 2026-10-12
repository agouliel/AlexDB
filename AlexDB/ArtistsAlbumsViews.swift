import SwiftUI

struct ArtistsView: View {
    var body: some View {
        NavigationStack {
            PagedList<ArtistRow, ArtistCell>(path: "/songs/artists_data/") { ArtistCell(row: $0) }
                .navigationTitle("Artists")
                .navigationDestination(for: ArtistRow.self) { ArtistAlbumsView(artist: $0.artist) }
        }
    }
}

struct ArtistCell: View {
    let row: ArtistRow
    var body: some View {
        NavigationLink(value: row) {
            HStack {
                Text(row.artist)
                Spacer()
                Text("\(row.song_count)").foregroundStyle(.secondary)
            }
        }
    }
}

struct ArtistAlbumsView: View {
    let artist: String

    private var path: String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let enc = artist.addingPercentEncoding(withAllowedCharacters: allowed) ?? artist
        return "/songs/artists/\(enc)/albums_data/"
    }

    var body: some View {
        PagedList<ArtistAlbum, ArtistAlbumCell>(path: path) { ArtistAlbumCell(album: $0) }
            .navigationTitle(artist)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct ArtistAlbumCell: View {
    let album: ArtistAlbum
    var body: some View {
        DisclosureGroup {
            ForEach(album.songs, id: \.self) { Text($0).font(.subheadline) }
        } label: {
            HStack {
                Text(album.album)
                Spacer()
                Text("\(album.song_count)").foregroundStyle(.secondary)
            }
        }
    }
}

struct AlbumsView: View {
    var body: some View {
        NavigationStack {
            PagedList<AlbumRow, AlbumCell>(path: "/songs/albums_data/") { AlbumCell(row: $0) }
                .navigationTitle("Albums")
                .navigationDestination(for: String.self) { ArtistAlbumsView(artist: $0) }
        }
    }
}

struct AlbumCell: View {
    let row: AlbumRow
    var body: some View {
        let content = HStack {
            VStack(alignment: .leading) {
                Text(row.album)
                if let a = row.artist, !a.isEmpty {
                    Text(a).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(row.song_count)").foregroundStyle(.secondary)
        }
        if let a = row.artist, !a.isEmpty {
            NavigationLink(value: a) { content }
        } else {
            content
        }
    }
}
