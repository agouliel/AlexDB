import SwiftUI

@MainActor
final class PagedLoader<Row: Decodable & Identifiable>: ObservableObject {
    @Published var rows: [Row] = []
    @Published var total = 0
    @Published var loading = false
    @Published var error: String?

    let path: String
    private var search = ""
    private var generation = 0

    init(path: String) { self.path = path }

    func reload(api: APIClient, search: String) async {
        self.search = search
        generation += 1
        rows = []
        total = 0
        await loadMore(api: api)
    }

    func loadMore(api: APIClient) async {
        guard !loading, rows.isEmpty || rows.count < total else { return }
        loading = true
        let gen = generation
        defer { if gen == generation { loading = false } }
        do {
            let page = try await api.fetchPage(path, as: Row.self, search: search, start: rows.count)
            guard gen == generation else { return }
            rows += page.data
            total = page.recordsFiltered
            error = nil
        } catch is CancellationError {
        } catch {
            if gen == generation { self.error = error.localizedDescription }
        }
    }
}

/// Searchable, infinitely scrolling list backed by a DataTables endpoint.
struct PagedList<Row: Decodable & Identifiable, Cell: View>: View {
    @EnvironmentObject var api: APIClient
    @StateObject private var loader: PagedLoader<Row>
    @State private var query = ""
    private let cell: (Row) -> Cell

    init(path: String, @ViewBuilder cell: @escaping (Row) -> Cell) {
        _loader = StateObject(wrappedValue: PagedLoader<Row>(path: path))
        self.cell = cell
    }

    var body: some View {
        List {
            if let err = loader.error {
                Text(err).foregroundStyle(.red)
            }
            ForEach(loader.rows) { row in
                cell(row)
                    .task {
                        if row.id == loader.rows.last?.id { await loader.loadMore(api: api) }
                    }
            }
            if loader.loading { ProgressView().frame(maxWidth: .infinity) }
        }
        .overlay {
            if !loader.loading && loader.rows.isEmpty && loader.error == nil {
                ContentUnavailableView("No results", systemImage: "magnifyingglass")
            }
        }
        .searchable(text: $query)
        .task(id: query) {
            // Debounce typing; also runs on first appearance and on baseURL change
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            guard !Task.isCancelled else { return }
            await loader.reload(api: api, search: query)
        }
        .refreshable { await loader.reload(api: api, search: query) }
    }
}
