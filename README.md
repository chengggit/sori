### Local reading

In the desktop app, open **My Library** and choose **Import** to add a UTF-8
`.txt` file up to 2 MiB. Select the imported document to read it. Sori stores a
copy in its local SQLite database so the document stays available after restart.

The Rust backend initializes `library.sqlite3` in the application data directory
at startup and applies versioned SQL migrations transactionally. Existing text
libraries are preserved. Document validation and persistence are independent of
Tauri commands, which run database operations on blocking workers.

Run backend tests with `cargo test --manifest-path src-tauri/Cargo.toml --locked`.

The vocabulary backend exposes `save_vocabulary`, `list_vocabulary`, and
`remove_vocabulary`, with typed calls in
`src/lib/features/vocabulary/vocabulary.ts`. It stores the selected word, an
optional normalized form, the document title and context, and a save timestamp.
Repeated saves of the same word and context in one document return the original
entry. Saved words survive source document deletion. Reader controls for saving
and browsing vocabulary are planned in the interactive reader phase.

### YouTube discovery

Sori can open a YouTube video link from Home without an API key. For automatic
discovery and search, enable YouTube Data API v3 in a Google Cloud project, then
set `VITE_YOUTUBE_API_KEY` in `.env.local` before starting or building Sori.
Use an API-restricted key for local development. This build variable is visible
in the desktop bundle, so keep any shared production credential server-side.
The player requires an internet connection. Use **Open on YouTube** if a video
cannot play in the embedded player.
