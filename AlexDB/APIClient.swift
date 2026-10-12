import Foundation

/// A DataTables-style page as returned by the Django `*_data/` endpoints.
struct DTPage<T: Decodable>: Decodable {
    let recordsTotal: Int
    let recordsFiltered: Int
    let data: [T]
}

enum APIError: LocalizedError {
    case badURL
    case http(Int)
    case notLoggedIn
    case formRejected
    case loginFailed

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid server URL."
        case .http(let c): return "Server returned HTTP \(c)."
        case .notLoggedIn: return "Please log in first (More tab)."
        case .formRejected: return "The server rejected the form."
        case .loginFailed: return "Login failed. Check username and password."
        }
    }
}

/// Talks to the Django app. Reads use the existing DataTables JSON endpoints;
/// writes post the existing HTML forms using Django's session + CSRF protocol.
@MainActor
final class APIClient: ObservableObject {
    static let defaultBaseURL = "https://goulielmos.org"

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "baseURL") }
    }
    @Published private(set) var isLoggedIn = false
    @Published private(set) var username: String?

    private let session: URLSession

    init() {
        baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? Self.defaultBaseURL
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpShouldSetCookies = true
        session = URLSession(configuration: cfg)
        username = UserDefaults.standard.string(forKey: "username")
        isLoggedIn = cookie("sessionid") != nil && username != nil
    }

    // MARK: URLs

    private func url(_ path: String, query: [URLQueryItem] = []) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard var comps = URLComponents(string: trimmed + "/django" + path) else { throw APIError.badURL }
        if !query.isEmpty { comps.queryItems = query }
        guard let u = comps.url else { throw APIError.badURL }
        return u
    }

    private func cookie(_ name: String) -> String? {
        guard let u = try? url("/") else { return nil }
        return HTTPCookieStorage.shared.cookies(for: u)?.first { $0.name == name }?.value
    }

    // MARK: Reads (existing JSON endpoints, no login required)

    func fetchPage<T: Decodable>(_ path: String, as type: T.Type, search: String,
                                 start: Int, length: Int = 25,
                                 orderColumn: Int = 0, desc: Bool = false) async throws -> DTPage<T> {
        let q = [
            URLQueryItem(name: "draw", value: "1"),
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "length", value: String(length)),
            URLQueryItem(name: "search[value]", value: search),
            URLQueryItem(name: "order[0][column]", value: String(orderColumn)),
            URLQueryItem(name: "order[0][dir]", value: desc ? "desc" : "asc"),
        ]
        let (data, resp) = try await session.data(from: try url(path, query: q))
        try check(resp)
        return try JSONDecoder().decode(DTPage<T>.self, from: data)
    }

    // MARK: Auth (Django session login form)

    func login(username: String, password: String) async throws {
        let loginURL = try url("/users/login/")
        let (_, getResp) = try await session.data(from: loginURL)
        try check(getResp)
        guard let token = cookie("csrftoken") else { throw APIError.loginFailed }

        let (_, resp) = try await postForm(loginURL, fields: [
            "username": username, "password": password,
            "csrfmiddlewaretoken": token, "next": "",
        ])
        // A failed login re-renders the login page; a success redirects elsewhere.
        if resp.url?.path.hasSuffix("/users/login/") == true || cookie("sessionid") == nil {
            throw APIError.loginFailed
        }
        self.username = username
        UserDefaults.standard.set(username, forKey: "username")
        isLoggedIn = true
    }

    func logout() async {
        if let u = try? url("/users/logout/") {
            _ = try? await session.data(from: u)
        }
        if let u = try? url("/"), let cs = HTTPCookieStorage.shared.cookies(for: u) {
            cs.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        }
        UserDefaults.standard.removeObject(forKey: "username")
        username = nil
        isLoggedIn = false
    }

    // MARK: Writes (existing HTML form endpoints)

    func saveSong(_ song: SongDraft, id: Int?) async throws {
        guard isLoggedIn else { throw APIError.notLoggedIn }
        let path = id.map { "/songs/edit_song/\($0)" } ?? "/songs/new_song/"
        try await submitForm(path: path, failMarker: id == nil ? "new_song" : "edit_song", fields: [
            "title": song.title, "artist": song.artist, "album": song.album,
            "composer": song.composer, "comment": song.comment,
        ])
    }

    func deleteSong(id: Int) async throws {
        guard isLoggedIn else { throw APIError.notLoggedIn }
        try await submitForm(path: "/songs/delete_song/\(id)", failMarker: "delete_song", fields: [:])
    }

    /// GETs the form page for a CSRF cookie, then POSTs. Because the server
    /// answers success with a redirect and validation errors with a re-rendered
    /// form, success is detected by the final URL no longer being the form's.
    private func submitForm(path: String, failMarker: String, fields: [String: String]) async throws {
        let target = try url(path)
        let (_, getResp) = try await session.data(from: target)
        if getResp.url?.path.contains("/users/login") == true {
            await logout()
            throw APIError.notLoggedIn
        }
        guard let token = cookie("csrftoken") else { throw APIError.formRejected }
        var all = fields
        all["csrfmiddlewaretoken"] = token
        let (_, resp) = try await postForm(target, fields: all)
        if resp.url?.path.contains(failMarker) == true { throw APIError.formRejected }
    }

    private func postForm(_ target: URL, fields: [String: String]) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: target)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(target.absoluteString, forHTTPHeaderField: "Referer") // required by Django over HTTPS
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=")
        req.httpBody = fields.map { k, v in
            "\(k)=\(v.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&").data(using: .utf8)
        let (data, resp) = try await session.data(for: req)
        let http = try check(resp)
        return (data, http)
    }

    @discardableResult
    private func check(_ resp: URLResponse) throws -> HTTPURLResponse {
        guard let http = resp as? HTTPURLResponse else { throw APIError.http(0) }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
        return http
    }
}
