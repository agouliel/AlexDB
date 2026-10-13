# Copilot Instructions

SwiftUI iOS 17+ client for a Django site (`https://goulielmos.org`, all routes under `/django/`). No third-party dependencies, no test target, no linter.

## Build & run

The Xcode project is **generated** from `project.yml` with XcodeGen (`brew install xcodegen`). Edit `project.yml` for target/build-setting changes, then regenerate; `AlexDB.xcodeproj` is also committed.

```sh
xcodegen generate
xcodebuild -project AlexDB.xcodeproj -scheme AlexDB \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build

# run in simulator (find a device UDID with: xcrun simctl list devices available)
xcrun simctl boot $UDID
xcrun simctl install $UDID build/Build/Products/Debug-iphonesimulator/AlexDB.app
xcrun simctl launch $UDID org.goulielmos.AlexDB
```

`build/` and `DerivedData/` are gitignored. Info.plist is generated (`INFOPLIST_KEY_*` settings in `project.yml`), so there is no Info.plist file to edit.

## Architecture

- `APIClient` (`@MainActor ObservableObject`, injected as an `@EnvironmentObject` from `AlexDBApp`) is the only networking layer. It owns the base URL (persisted in `UserDefaults`, editable in the More tab), login state, and a `URLSession` backed by `HTTPCookieStorage.shared`.
- **Reads** hit existing Django DataTables JSON endpoints (`songs_data/`, `artists_data/`, `albums_data/`, `artists/<artist>/albums_data/`) via `fetchPage`, decoded into `DTPage<T>`.
- `PagedList` / `PagedLoader` is the generic searchable, infinite-scroll list over any DataTables endpoint. A `generation` counter discards stale responses when the search changes; reuse it for new list screens instead of writing new paging logic.
- **Auth and writes** have no JSON API. Login and song add/edit/delete post the server's HTML forms: GET the page to obtain the `csrftoken` cookie, then POST form-encoded with `csrfmiddlewaretoken` and a `Referer` header (required by Django over HTTPS). Success or failure is inferred from the **final redirect URL** (`submitForm`, `login`), so changes to server routes/redirects break these. Passwords are never persisted; only the session cookie and username are.
- Books, Tickets, and Files are placeholder screens in `MoreView` because the server has no JSON endpoints for them. `API_NOTES.md` is the source of truth for which endpoints exist, which are missing, and known server-side auth issues; update it when endpoint usage changes.

## Conventions

- Artist names in URL paths must be percent-encoded with `urlPathAllowed` minus `/` (spaces break `URLComponents`).
- Form bodies are encoded manually, with `&`, `+`, `=` removed from the allowed set.
- Keep the default base URL HTTPS (ATS); only local networking is exempted.
