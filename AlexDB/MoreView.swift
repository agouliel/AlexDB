import SwiftUI

struct MoreView: View {
    @EnvironmentObject var api: APIClient

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if api.isLoggedIn {
                        LabeledContent("Signed in as", value: api.username ?? "")
                        Button("Log out", role: .destructive) { Task { await api.logout() } }
                    } else {
                        NavigationLink("Log in") { LoginView() }
                    }
                }
                Section("Server") {
                    TextField("Base URL", text: $api.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                Section("Not yet available (needs server API)") {
                    NavigationLink("Books") { MissingAPIView(title: "Books", needs: [
                        "GET  /django/api/books/  (list + ?q= search, owner-scoped)",
                        "CRUD /django/api/books/<id>/",
                        "GET  /django/api/categories/, /locations/, /sites/",
                    ]) }
                    NavigationLink("Tickets") { MissingAPIView(title: "Tickets", needs: [
                        "GET  /django/api/tickets/ and /tickets/<id>/ (with comments)",
                        "POST /django/api/tickets/",
                        "POST /django/api/tickets/<id>/comments/",
                    ]) }
                    NavigationLink("Files") { MissingAPIView(title: "Files", needs: [
                        "GET  /django/api/files/",
                        "POST /django/api/files/ (multipart upload)",
                    ]) }
                }
            }
            .navigationTitle("More")
        }
    }
}

struct MissingAPIView: View {
    let title: String
    let needs: [String]
    var body: some View {
        List {
            Section {
                Text("The Django app only exposes this data through HTML pages. These JSON endpoints must be added first (see API_NOTES.md):")
            }
            Section("Required") {
                ForEach(needs, id: \.self) { Text($0).font(.system(.footnote, design: .monospaced)) }
            }
        }
        .navigationTitle(title)
    }
}

struct LoginView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Form {
            TextField("Username", text: $username)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            SecureField("Password", text: $password)
            if let error { Text(error).foregroundStyle(.red) }
            Button("Log in") {
                busy = true
                Task {
                    defer { busy = false }
                    do { try await api.login(username: username, password: password); dismiss() }
                    catch { self.error = error.localizedDescription }
                }
            }
            .disabled(busy || username.isEmpty || password.isEmpty)
        }
        .navigationTitle("Log in")
    }
}
