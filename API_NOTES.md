# AlexDB iOS – Django API status

Base URL (editable in app, More tab): `https://goulielmos.org`. All routes live under `/django/`.

## Used by the app today (existing)

| Feature | Endpoint | Auth |
|---|---|---|
| Songs list/search/paging | `GET /django/songs/songs_data/` (DataTables params) | none |
| Artists | `GET /django/songs/artists_data/` | none |
| Albums | `GET /django/songs/albums_data/` | none |
| Albums of an artist (+ song titles) | `GET /django/songs/artists/<artist>/albums_data/` | none |
| Login | `POST /django/users/login/` (form + CSRF cookie + Referer) | session cookie |
| Add song | `POST /django/songs/new_song/` (form + CSRF) | `@login_required` |
| Edit song | `POST /django/songs/edit_song/<id>` (form + CSRF) | `@login_required` |
| Delete song | `POST /django/songs/delete_song/<id>` (DeleteView + CSRF) | **none (see below)** |

Write calls are form posts; the app detects success/failure from the redirect target. A real JSON API
would be more robust (see below).

## Missing – must be added on the Django side

No JSON API exists for these; they only render HTML (and `books` views are `@login_required`/owner-scoped).
Suggested: add `djangorestframework` (+ `TokenAuthentication` or `SessionAuthentication`) and routes under
`/django/api/`.

1. **Authentication** – a token/JSON login endpoint (`POST /django/api/auth/login/` → token) so the app
   doesn't need to scrape CSRF cookies. GitHub OAuth (allauth) can't be used from the app as-is.
2. **Books** – `GET /api/books/?q=` (search title/title_en/author/publisher/translator/comment, filtered
   by `owner=request.user`), `POST`, `PUT/PATCH`, `DELETE /api/books/<bid>/`. Fields: bid, title, title_en,
   author, translator, publisher, comment, location, category.
3. **Categories / Sites / Locations** – list + create + delete (`Tblbookscateg`, `Tblbksites`,
   `Tblbookslocations`; locations filterable by `?site=`, replacing the HTML `ajax/load-locations/`),
   plus books-by-category/location and the `move_books` action.
4. **Tickets** – `GET /api/tickets/`, `GET /api/tickets/<id>/` (with `comments`), `POST /api/tickets/`
   (title, description, priority, ticket_type; `created_by` from user),
   `POST /api/tickets/<id>/comments/`. Current views render templates and `redirect(reverse('tickets'))`.
5. **Files** – `GET /api/files/` (fname, URL under `/django/media/`), `POST /api/files/` multipart upload.
   Note the existing upload view writes to a relative `media/` path.
6. **Songs** – JSON create/update/delete (`POST/PUT/DELETE /api/songs/<sid>/`), plus an autocomplete
   list for artists/albums (currently only embedded in HTML templates).

## Server issues noticed

- `DeleteSong` (`songs/views.py`) has **no `@login_required`**; `songs_data` & friends are public too.
  Anyone can delete songs via POST with a CSRF token. Add `LoginRequiredMixin`.
- `new_song_modal` and `tickets.add_comment_to_ticket` are also unauthenticated.
- `/django/media/` serves files publicly.
- CORS isn't needed for a native app, but `CSRF_TRUSTED_ORIGINS` must include the host used by the app.
