### Desktop development

After installing the JavaScript and Rust dependencies, run `npm run setup:kiwi`
once before building or starting the desktop app. This requires Node.js 22+,
`tar`, and internet access to download the pinned Kiwi 0.24.0 native library and
base model. The script verifies upstream SHA-256 checksums and prepares resources
for the host platform. Downloaded resources are ignored by Git and included in
Tauri app bundles, so installed apps analyze Korean offline.

Run setup on the machine/architecture that builds the desktop app. The script
has assets for Linux x64/ARM64, macOS x64/ARM64, and Windows x64. Linux x64 has
been integration-tested. Native packaging on other platforms still needs testing.

### Local reading

In the desktop app, open **My Library** and choose **Import** to add a UTF-8
`.txt` file up to 2 MiB. Select the imported document to open its dedicated reader
page. Use **Library** in the reader header to return to your documents. Sori stores a
copy in its local SQLite database so the document stays available after restart.

The reader saves your relative scroll position locally and restores it when you
reopen a document. It saves while scrolling and when the reader closes. Restoring
uses the current window size, so the exact line may shift after resizing.

The reader analyzes passages as they approach the viewport and renders
whole words as clickable boxes, with punctuation displayed as plain text.
Click a whole word to open the
right-hand panel with its individual morphemes, readable word-type labels, POS
tags and original context, then save or remove the vocabulary entry. The original
word is saved by default, with an optional morpheme form to collect.

The panel first searches the complete selected word, then its reconstructed
dictionary form if needed, and shows the matching English meanings above the
breakdown. Prefixes and compound stems stay together during lookup. Select a
meaning to save it with the original word and context.

The panel also automatically shows English meanings beside the word breakdown using
Wiktionary without an API key. Common endings and particles have short offline
grammar explanations keyed by their analyzed form and POS. Other morphemes use
dictionary definitions when available. Manual lookup is under **Search dictionary**. Verb
and adjective stems use the `다` form, and particles/endings use a leading hyphen.
Select a meaning before saving a word to keep that definition and its source
locally for offline reading. Existing vocabulary without meanings remains usable.
The panel also links to the full Wiktionary entry and Naver in the system browser.
The sidebar tabs offer **Analysis**, **Naver**, and **Papago**.
The latter two load their full websites inside the resizable sidebar
with the selected word prefilled. Users can edit the query or open the page in
their browser. These views need internet access. Use Analysis to save vocabulary
and selected Wiktionary definitions locally.
Definitions are plain text attributed to Wiktionary contributors under CC BY-SA
4.0. Lookup uses Wiktionary's experimental definition endpoint, so coverage and
availability can vary. Saved meanings require no network request.

Run the optional live dictionary check with
`cargo test --manifest-path src-tauri/Cargo.toml dictionary::tests::live_korean_lookup -- --ignored`.

Token rendering checks can be run with
`node --experimental-strip-types --test scripts/reader-tokens.test.mjs`.

The Rust backend initializes `library.sqlite3` in the application data directory
at startup using `src-tauri/src/schema.sql` in a transaction. During pre-release
development, keep the schema at version 1 and edit that file as features evolve.
Incremental migrations will begin when released builds need to preserve user data.
Changes to existing table definitions may require an explicit development database
reset. Startup creates missing tables and retains existing data, including local
databases marked version 2 or 3 by earlier development builds.

Document validation and persistence are independent of Tauri commands, which run
database operations on blocking workers.

Run backend tests with `cargo test --manifest-path src-tauri/Cargo.toml --locked`.

### Korean tokenization backend

The `tokenize_text` command analyzes passages up to 16 KiB of UTF-8 text using
`kiwi-rs` 2026.10.17 and the bundled Kiwi model. Typed frontend calls live in
`src/lib/features/nlp/tokenization.ts`. Each token includes its morpheme form,
POS tag, original surface, word/sentence indices, and start/end offsets in UTF-16
code units for JavaScript string slicing. Morphemes from contractions can share
overlapping source spans. A verb stem such as `가` is an analyzed morpheme form.

Kiwi loads on first use, verifies UTF-16 API support, and stays on a dedicated
worker thread. Empty input returns an empty list. Invalid input and resource
errors return command errors, and a bounded request queue reports when analysis
is busy.

After setup, run the real offline model test with
`cargo test --manifest-path src-tauri/Cargo.toml --locked nlp::tests::analyzes_korean_offline_with_utf16_offsets -- --ignored`.

The native Kiwi 0.24.0 license (Apache-2.0) is in
`src-tauri/third-party/Kiwi-LICENSE`. The Rust wrapper license (LGPL-2.1-or-later)
is in `src-tauri/third-party/kiwi-rs-LICENSE`. Setup copies both license files into
app resources, including when the library and model are already cached. Upstream sources
are [Kiwi](https://github.com/bab2min/Kiwi/tree/v0.24.0) and
[kiwi-rs](https://github.com/JAICHANGPARK/kiwi-rs).

The vocabulary backend exposes `save_vocabulary`, `list_vocabulary`, and
`remove_vocabulary`, with typed calls in
`src/lib/features/vocabulary/vocabulary.ts`. It stores the selected word, an
optional normalized form, the document title and context, and a save timestamp.
Repeated saves of the same word and context in one document return the original
entry. Saved words survive source document deletion. The reader supports saving
and removing vocabulary in context. Open **Vocabulary** in the sidebar to browse
saved words newest first, search by the word you entered, and edit or remove
entries from their three-dot menus. Saved meanings are available offline.

### Watching local videos

Open **My Library → Import → Choose video** and select a local video. Sori
references the original file and saves your playback position. The desktop
webview handles video playback, so codec support depends on the system. On
Linux, Sori streams local videos over loopback HTTP.

Install FFmpeg and make both `ffmpeg` and `ffprobe` available on the app’s PATH
for embedded subtitle tracks. Sori converts embedded text tracks such as SRT,
ASS, SSA, WebVTT, and MP4 timed text into interactive cues. Select a track in
**Subtitles**, or attach a UTF-8 SRT or WebVTT file. Local video attachments are
stored in the library. Image-based tracks require a text subtitle file for word
lookup.

Click a subtitle word to pause, see its analysis, and save it to Vocabulary.
You can also attach a subtitle file while watching YouTube. The attachment lasts
for that viewing session, and the embed’s CC button provides YouTube captions.

The Linux Watch screen has **Try MP4 streaming (experimental)**.
It uses FFmpeg to stream compatible audio and video tracks without creating a
second video file. Seeking restarts the stream near a keyframe. Sori reads
subtitles directly from the original file.

### YouTube discovery

Sori can open a YouTube video link from Home without an API key. For automatic
discovery and search, enable YouTube Data API v3 in a Google Cloud project, then
set `VITE_YOUTUBE_API_KEY` in `.env.local` before starting or building Sori.
Use an API-restricted key for local development. This build variable is visible
in the desktop bundle, so keep any shared production credential server-side.
The player requires an internet connection. Use **Open on YouTube** if a video
cannot play in the embedded player.
