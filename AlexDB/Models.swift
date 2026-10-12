import Foundation

struct Song: Decodable, Identifiable, Hashable {
    let sid: Int
    let title: String?
    let artist: String?
    let album: String?
    let composer: String?
    let comment: String?
    var id: Int { sid }
}

struct SongDraft {
    var title = ""
    var artist = ""
    var album = ""
    var composer = ""
    var comment = ""

    init() {}
    init(_ s: Song) {
        title = s.title ?? ""; artist = s.artist ?? ""; album = s.album ?? ""
        composer = s.composer ?? ""; comment = s.comment ?? ""
    }
}

struct ArtistRow: Decodable, Identifiable, Hashable {
    let artist: String
    let song_count: Int
    var id: String { artist }
}

struct AlbumRow: Decodable, Identifiable, Hashable {
    let album: String
    let artist: String?
    let song_count: Int
    var id: String { album + "\u{0}" + (artist ?? "") }
}

struct ArtistAlbum: Decodable, Identifiable, Hashable {
    let album: String
    let song_count: Int
    let songs: [String]
    var id: String { album }
}
