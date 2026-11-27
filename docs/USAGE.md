# Using Sori

## Reading and vocabulary

Import TXT files or PDFs, or paste text in My Library. Click Korean words to
analyze them and save vocabulary with context. Meanings, notes, and tags can be
edited later; saving words with your own meaning works offline.

PDFs offer **Book** and **Scroll** views. In Book view, turn pages with the
arrow buttons; in Scroll view, all pages are listed continuously. Scanned PDFs
can be viewed, but word selection requires an embedded text layer.

Reading and player progress are saved locally and restored when you reopen an
item. Reader font, size and line height are adjustable in Settings.

## Watching

| Control              | Action                                          |
| -------------------- | ----------------------------------------------- |
| Space                | Play/pause                                      |
| Left/Right           | Seek five seconds                               |
| F / Esc              | Enter/exit fullscreen                           |
| C                    | Show/hide captions                              |
| Transcript timestamp | Seek to that line                               |
| Caption/transcript word | Look up and save vocabulary                  |

Use the **Primary** and **Secondary** selectors to choose subtitle tracks, or
**Attach SRT/VTT** to add a sidecar. Clicking a transcript cue seeks to it;
manual scrolling suspends automatic following until **Resume follow** is used.

## Dictionaries

Choose the analysis dictionary in Settings. Wiktionary doesn't need an API key.
KRDict requires an API key and falls back to Wiktionary when no definitions are
found. Saved meanings remain available offline; live lookups need internet.

Embedded lookup tabs (Naver, Papago and custom HTTPS templates) are separate
from the analysis provider. Enable, drag-reorder, or remove them in Settings.

## YouTube

Open **Explore** to paste an embeddable video link or search with a YouTube Data
API key. A saved key takes priority over `SORI_YOUTUBE_API_KEY` or
`.env.local`; removing it restores that fallback. Capture Korean captions with
**Fetch captions** when the optional helper is available. Channel subscriptions
and the uploads feed are managed on the same page.

## Settings

Settings covers theme (system/light/dark), application zoom, reading typography,
dictionary provider and keys, YouTube key, and embedded tab order. All
preferences are stored locally.

## Offline behavior

Reading, local playback, Korean analysis, vocabulary and saved meanings work
offline. Dictionary lookups, YouTube search/discovery and caption fetching need
an internet connection. No account or AI service is ever required.
