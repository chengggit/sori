# Using Sori

## Reading and vocabulary

Import TXT files or PDFs, or paste text in My Library. Click Korean words to
analyze them and save vocabulary with context. Meanings, notes, and tags can be
edited later; saving words with your own meaning works offline.

PDFs offer **Book** and **Scroll** views. In Book view, turn pages with the
arrows, Left/Right keys, or the left/right half of the page area. Scanned PDFs
can be viewed, but word selection requires an embedded text layer.

## Watching

| Control                        | Action                                         |
| ------------------------------ | ---------------------------------------------- |
| Space                          | Play/pause                                     |
| Left/Right                     | Seek five seconds                              |
| F / Esc                        | Enter/exit fullscreen                          |
| CC                             | Select subtitle tracks or attach SRT/VTT files |
| Transcript timestamp           | Seek to that line                              |
| Korean caption/transcript word | Look up and save vocabulary                    |

Image-based subtitle tracks are unsupported. In fullscreen, **Open in sidebar**
expands a word lookup. Closing the lookup resumes playback if it was playing
before the lookup opened.

Scrolling the subtitle transcript pauses automatic following. **Resume follow**,
a timestamp click, or five seconds of inactivity resumes it.
**Add transcript** attaches an untimed UTF-8 TXT file to a local or YouTube video,
with an independent saved reading position.

## Dictionaries

Choose the analysis dictionary in Settings. Wiktionary doesn't need an API key. KRDict
requires an API key and falls back to Wiktionary when no definitions are found.
Saved definitions remain available offline; live lookups need internet.

We recommend KRDict as your main dictionary, with Wiktionary as a fallback.
Request a key through the
[KRDict API application page](https://krdict.korean.go.kr/eng/openApi/openApiRegister),
then add it in Settings.

Embedded lookup tabs are separate from the analysis provider. Enable and drag
them into your preferred order in Settings. Custom tabs accept HTTPS URLs with
`{word}` for the selected word. Embedded KRDict doesn't need an API key.

## YouTube

Paste a YouTube video link to watch without an API key. Search and discovery require
a YouTube Data API key in Settings. A saved key takes priority over
`SORI_YOUTUBE_API_KEY` or `.env.local`; removing it restores that fallback.

You can obtain one from [Google Cloud Console](https://console.cloud.google.com/).

The optional caption helper fetches existing Korean captions and caches them
locally. It needs internet, but no Data API key. It does not transcribe audio,
translate text, or fall back to English. Missing captions and network failures
appear in the page. Use **Open in browser** if a video cannot be embedded.
