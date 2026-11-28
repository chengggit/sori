# Using Sori

## Home

Home shows your most recently watched local or YouTube video with saved progress
and a Resume link. Local resume works offline. If nothing has been watched yet,
Open Library takes you to your imported media.

The search field in the header searches YouTube. With an API key configured,
Home discovers uploads from the channels managed in Explore. Refresh reloads
the feed; Load more appends another page. Paste YouTube link opens an embeddable
video without an API key. YouTube videos open in Watch.

## Library

My Library separates text/PDF covers and local video cards. Search matches titles;
video cards show stored playback progress. Open a cover to read or watch. Hover
or keyboard-focus a card to reveal its item menu; touch layouts keep menus visible.

Import text opens a dialog for pasted text or a native TXT/PDF file picker.
Text entries can be edited from their item menu. PDFs remain read-only in the
text editor. Delete removes a document and any managed PDF copy; removing a video
only removes its library entry and leaves the original media file on disk.

## Reading and vocabulary

Import TXT files or PDFs, or paste text in My Library. Click Korean words to
analyze them and save vocabulary with context. Meanings, notes, and tags can be
edited later; saving words with your own meaning works offline.

Vocabulary lists your saved words with search, type filters and sorting. Click a
word to open its details on the right; drag the divider to resize it, or focus
the divider and use Left/Right. Escape closes the details. The three-dot menu
offers **Edit** and **Remove**; removal asks for confirmation. Editing the
dictionary form, meaning, tags or note keeps the original word and source context.
A note needs a meaning. Saved context and meanings remain after removing their
source document or video from My Library.

PDFs offer **Book** and **Scroll** views. In Book view, turn pages with the
toolbar arrows, Left/Right keys, or the blank left/right halves of a page.
Book fits the page to the window; Scroll lists wider pages continuously. The
mode toggle preserves the current page. Use −/+ to zoom, or click the percentage
to reset it to 100%. Scanned PDFs
can be viewed, but word selection requires an embedded text layer.

Reading and player progress are saved locally and restored when you reopen an
item. Reader font, size and line height are adjustable in Settings.

## Watching

| Control                 | Action                      |
| ----------------------- | --------------------------- |
| Space                   | Play/pause                  |
| Left/Right              | Seek five seconds           |
| F / Esc                 | Enter/exit fullscreen       |
| C                       | Show/hide captions          |
| Transcript timestamp    | Seek to that line           |
| Caption/transcript word | Look up and save vocabulary |

Local Watch uses controls over the video: timeline, play/pause, mute, volume,
CC and fullscreen. Controls fade during playback and remain visible while paused.
Open **CC** for primary/secondary tracks, **Show subtitles**, and **Add subtitle
files**. Attached SRT/VTT content is saved locally and restored on reopening.

The transcript sits below the video. Its timestamps seek; Korean words open the
analysis sidebar. Manual scrolling pauses following and offers **Resume follow**;
following also resumes after five seconds without interaction. **Add transcript**
imports a UTF-8 TXT file. Switch between text and timed subtitles, or use the
three-dot menu to replace/remove the text. Text reading position is saved locally.

Clicking a caption word pauses playback and opens a compact definition popup.
Use its bookmark to save quickly, or **Open full analysis** for meanings, tags,
notes and dictionary tabs. Closing lookup resumes playback only if it was playing
when lookup began. Fullscreen keeps lookup tools inside the player.

YouTube opens in the same Watch layout with its embedded player controls and
cached/fetched transcript. Its playback and codec support remain controlled by
YouTube. Local playback uses Chromium's supported codecs; alternate local audio
track selection is not currently exposed.

## History

History combines local and YouTube watch records, newest first by their saved
watch timestamps. Local imports without a watch record stay in My Library until
playback progress is recorded. Duration badges and progress bars use stored
values; videos with an unknown duration show the time watched instead.

Open a row to resume in Watch; Back returns to History and restores your list
position for this app session. If an original local
video was moved or removed, History keeps the record and shows the error without
leaving the list. History reads saved titles and progress locally; YouTube
playback and remote thumbnails still need a connection. Local thumbnails are
prepared as rows come into view.

## Word analysis and saving

Click a Korean word in Reader or a Watch transcript to open the shared panel.
Analysis looks up the selected word and its dictionary form automatically. Click
a meaning to select it, then use the bookmark button to open Save word. You can
change the word, meaning, comma-separated tags and optional note before saving.
Words can also be saved with your own meaning offline, or without a meaning.
Open a filled bookmark to edit or remove the saved entry.

Dictionary tabs stay beside Analysis. Use arrow keys to switch tabs, or drag /
Alt+Arrow keys to reorder the enabled dictionaries. The save draft survives tab
switches; inactive embedded pages are released after 30 seconds. If a dictionary
refuses embedding, use Open in browser. Sources lists the loaded definition links.

## Dictionaries

Choose the analysis dictionary in Settings. Wiktionary doesn't need an API key.
KRDict requires an API key and falls back to Wiktionary when no definitions are
found. Saved meanings remain available offline; live lookups need internet.

Embedded lookup tabs (Naver, Papago and custom HTTPS templates) are separate
from the analysis provider. Enable, drag-reorder, or remove them in Settings.

## YouTube

Open **Explore** to search YouTube or browse History, Science & nature, Food &
cooking, Comedy, Interviews, Arts & crafts, Music, and Daily life. Search and
topics require a YouTube Data API key in Settings. **Paste video link** opens an
embeddable video in Watch without a developer key. A saved key takes priority
over `SORI_YOUTUBE_API_KEY` or `.env.local`; removing it restores that fallback.

**Subscriptions** opens channel management. Add a channel link, @handle or channel
ID, or remove a saved channel. **Your feed** shows subscribed uploads; **Refresh
videos** reloads the selected topic, search or feed. Scroll near the end or use
**Load more** to append results. Failed requests offer Retry and retain loaded
pages. Search settings and channel errors remain separate.

Watch's Back action returns to Explore for videos opened there. Explore keeps
its last results and scroll position in memory for up to 15 minutes; restarting
the app clears this view state. Capture Korean captions in Watch with **Fetch
captions** when the optional helper is available.

## Settings

Settings covers theme (system/light/dark), application zoom, reading typography,
dictionary provider and keys, YouTube key, and embedded tab order. All
preferences are stored locally.

## Offline behavior

Reading, local playback, Korean analysis, vocabulary and saved meanings work
offline. Dictionary lookups, YouTube search/discovery and caption fetching need
an internet connection. No account or AI service is ever required.
