import SwiftUI

@main
struct AlexDBApp: App {
    @StateObject private var api = APIClient()

    var body: some Scene {
        WindowGroup {
            TabView {
                SongsView().tabItem { Label("Songs", systemImage: "music.note") }
                ArtistsView().tabItem { Label("Artists", systemImage: "person.2") }
                AlbumsView().tabItem { Label("Albums", systemImage: "square.stack") }
                MoreView().tabItem { Label("More", systemImage: "ellipsis") }
            }
            .environmentObject(api)
        }
    }
}
