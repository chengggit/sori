# Frontend rework checklist

## Direction

Use `/home/cheng/Documents/sori-tauri` as the starting point for the frontend's
layouts, components and interactions. The inspected source revision is
`891af0a`; check local changes there before copying a component. Leave that
checkout intact. Adapt one page at a time into the current Electron app.

Keep the root project layout, Vite/Svelte setup, Electron security boundary,
Rust services, SQLite library and existing native/media integrations. There is
no browser or localhost client in this plan. Product behavior follows
[PRODUCT.md](PRODUCT.md) and [USAGE.md](USAGE.md); the old UI supplies the design
starting point, including functionality missing from the current presentation.

Copy components and styles as needed, then connect them to current typed command
wrappers and `src/platform.ts`. Replace SvelteKit `$app` imports, route files and
navigation with the existing SPA routing. Do not copy Tauri dependencies,
capabilities, `src-tauri`, build output, secrets, direct YouTube API keys in the
renderer, browser database fallbacks, or mpv/Tauri player integrations.

## Branch workflow

- `main` remains the stable baseline.
- `feat/frontend-rework` is the integration branch for this entire rework.
- Start each branch below from the latest `feat/frontend-rework` after the
  preceding slice has merged. Work sequentially to keep shared UI changes small.
- Finish, validate and review one slice; commit it and merge it back into
  `feat/frontend-rework`. Return to the integration branch before starting the next.
- Keep each checklist item unchecked until its completion criteria and review
  are satisfied. Record validation and intentional design differences with it.
- Merge `feat/frontend-rework` into `main` only after the final acceptance pass.
  Creating this plan does not start implementation or perform any merges.

Example for the first slice:

```sh
git switch feat/frontend-rework
git switch -c feat/frontend-shell
# Implement, validate, review, and commit the slice.
git switch feat/frontend-rework
git merge --no-ff feat/frontend-shell
```

## Work order

- [x] **0. Shared shell — `feat/frontend-shell`**
      Reuse `src/routes/+layout.svelte`, `layout.css`, `AppSidebar.svelte`, and the
      sidebar/sheet/tooltip primitives from the old checkout. Copy only required
      dependencies/components, reconciling them with the current versions and tokens.
      Keep routed screens in `src/pages/` and reusable UI in `src/lib/`.
      Preserve navigation to existing pages while their replacements are pending.
      Establish route handling for changing item IDs without stale page state.
      Keep CI manual-only during the rework; run checks locally for each slice.
      **Done when:** sidebar, active navigation, collapse behavior, theme and zoom
      work with keyboard navigation, light/dark themes and narrow windows; existing
      screens remain usable. Capture a visual baseline for later page comparisons.

- [x] **1. Home — `feat/frontend-home`**
      Start from old `src/routes/+page.svelte`: dashboard layout, resume cards,
      YouTube link entry and discovery/search presentation. Use Rust-backed state
      and current YouTube commands; no renderer API key or duplicate local history.
      Reuse the existing working YouTube playback destination until the Watch slice
      provides a shared destination. Handle offline and missing-key states honestly.
      **Done when:** Home is populated by real library/history data, empty libraries
      have useful actions, resume links open the correct item, and optional online
      controls show loading/errors without blocking offline use.

- [x] **2. Library — `feat/frontend-library`**
      Start from old `src/routes/library/+page.svelte`: document/video shelves,
      search, import sheet, item actions, edit and remove flows. Keep current native
      file pickers, paste import, TXT/PDF support and Rust-owned metadata/progress.
      **Done when:** import, paste, search, edit, open and remove work on real sample
      data; PDF and video items retain their current capabilities; mutations refresh
      the page and removing an item preserves the original user media files.

- [x] **3. Analysis and dictionary panels — `feat/frontend-analysis`**
      Reuse old `features/reader` word breakdown, meaning and save panels plus
      `features/dictionary/EmbeddedLookup.svelte`. Adapt them to current Kiwi output,
      dictionary commands and vocabulary envelopes; retain UTF-16 offsets.
      Build this once for Reader and Watch instead of duplicating their analysis UI.
      **Done when:** a Korean word yields real analysis, meanings and editable save
      context; saved meanings work offline; dictionary errors, provider fallback,
      external links and embedded tab enable/order/retention behavior remain usable.

- [ ] **4. Reader — `feat/frontend-reader`**
      Start from old `src/routes/read/+page.svelte`, `DocumentReader.svelte`, and
      `TokenPassage.svelte`. Integrate the shared analysis panel and preserve the
      current PDF renderer rather than losing PDF support in a text-only port.
      **Done when:** TXT/PDF open, Korean selections reach analysis and vocabulary,
      Book/Scroll modes and reader typography work, progress saves/restores, and
      switching documents cannot apply stale analysis or progress to another item.

- [ ] **5. Watch — `feat/frontend-watch`**
      Start from old `src/routes/watch/+page.svelte` and `WatchVideo.svelte` layouts.
      Keep Electron's Chromium player and Range protocols; adapt the old controls,
      transcript and analysis layout without restoring mpv or Tauri video plugins.
      Integrate local video and YouTube destinations with their existing services.
      **Done when:** play/pause, seek, fullscreen, keyboard controls, dual subtitles,
      attachments, transcript seeking/following, word lookup/save and progress work;
      switching videos discards stale results and leaving playback flushes progress.
      Sidecar attachments must restore on reopening.

- [ ] **6. Explore — `feat/frontend-explore`**
      Start from old `src/routes/explore/+page.svelte`: topic browsing and search
      presentation. Retain current subscriptions/feed and caption-fetch workflows,
      even though the older page does not provide their full UI. Share video cards
      and navigation with Home and Watch.
      **Done when:** search/topic results, pagination, subscriptions/feed and opening
      a video work through Rust services; loading, missing keys, offline conditions,
      empty responses and failed requests have distinct states.

- [ ] **7. History — `feat/frontend-history`**
      Start from old `src/routes/history/+page.svelte`, replacing localStorage watch
      history with current Rust-backed YouTube history. Present local resume data
      where the existing services support it; inspect available timestamps before
      promising a combined chronological local/YouTube history. Any required service
      extension must be explicit and stay in Rust.
      **Done when:** the History navigation entry has a real page, accurate stored
      progress and working resume links; it updates after playback and has a useful
      empty state without inventing viewing records.

- [ ] **8. Vocabulary — `feat/frontend-vocabulary`**
      Start from old `src/routes/vocabulary/+page.svelte` and its relevant components.
      Retain the current search/filter/sort, meanings, notes, tags and source snapshots.
      **Done when:** Reader/Watch saves appear here; users can inspect, edit and remove
      entries; saved meanings work offline and survive removal of their source item.

- [ ] **9. Settings — `feat/frontend-settings`**
      Reuse the old layout's settings sheet presentation. Default to restoring the
      sidebar-opened sheet while preserving a direct settings route to the same
      controls. Reconcile that presentation with the current broader settings UI.
      **Done when:** theme, application zoom, reading/transcript typography,
      dictionary provider/key, YouTube key and embedded tabs remain configurable;
      persistence and saved-key/environment fallback semantics are preserved.

- [ ] **10. Final acceptance — `chore/frontend-acceptance`**
      Review every page against the old UI and current product requirements. Remove
      replaced components and unused assets/dependencies; fix cross-page styling,
      stale routes and duplicated state. Update design, usage and structure docs.
      Restore CI push/PR triggers with the intended branch filters.
      Run the full relevant check suite and packaged smoke flows with temporary
      libraries. Check Windows/macOS behavior and record any unavailable verification
      explicitly. Resolve regressions before merging the integration branch to main.
      **Done when:** all prior items are reviewed and checked, core workflows remain
      usable offline, integration checks pass, and the user accepts the final UI.

## Validation for each slice

Run `npm run typecheck`, `npm run build`, `npm run format:check`, relevant unit
checks and affected Playwright flows. Update assertions when intended behavior
changes; retain coverage for working features. Exercise native-dependent flows
in real Electron using temporary libraries, not only browser stubs. Add focused
regressions for behavior bugs; avoid tests that only mirror markup.

Visually review the changed screen in light/dark themes, a narrow window and
application zoom. Check loading, empty, error and populated states, keyboard
focus, and navigation away/back. Include screenshots for review. A copied layout
with disconnected controls is not a completed slice.

Backend rewrites, optional Rust-to-TypeScript ports, signing, release publishing,
and unrelated migration gaps are outside this frontend plan. Surface any backend
capability needed by a page before deciding whether to extend its service or
adjust that page's scope.

## Step 0 implementation notes

Implemented on `feat/frontend-shell` and accepted by the user on 2026-11-28.
Step 0 is complete and merged into `feat/frontend-rework`.

- Reused committed sidebar code from the old checkout, leaving its uncommitted
  native-video workaround untouched. Copied only used sidebar primitives plus
  their sheet/tooltip dependencies; no new npm dependencies were needed.
- Retained the current OKLCH palette and persisted preferences. Added an Appearance
  dialog for theme/zoom; the existing full Settings page remains accessible.
- Added keyed Reader/Watch item views and cancellation checks for pending loads.
- CI stays manual-only. Home and History remain for their planned page slices.
- Browser regressions cover mobile focus/navigation, desktop collapse, persisted
  theme/zoom, controls at 150% zoom, and switching IDs during a pending reader load.
- Visual baselines are generated in `test-results/shell-baseline/` (ignored build
  artifacts): `light.png`, `dark.png`, and `mobile.png`.
- Validation: typecheck, production build, formatting, 20 unit tests, 12 browser
  tests, and all 11 packaged Linux smoke routes passed with temporary libraries.
  Windows/macOS visual and packaged behavior has not been verified locally.

## Step 1 implementation notes

Implemented on `feat/frontend-home`, using the user-provided Qt screenshot and
`/home/cheng/Documents/sori-qt/qml/pages/{HomePage,ExplorePage}.qml` as the visual
and behavioral reference. The shell branch was merged into the integration
branch before this slice started. Step 1 was accepted by the user on 2026-11-28;
integration into `feat/frontend-rework` completed through PR #47.

- Home uses a header search form, a most-recent local/YouTube resume card, and a
  responsive discovery grid. Discovery follows Qt's subscription feed behavior;
  it explains missing keys/subscriptions rather than displaying sample content.
- Search and pagination use existing Rust services; obsolete responses are ignored,
  pages append without duplicates, and errors can be retried. Pasted links work
  without an API key and route to the existing Explore player.
- Added a restricted managed-thumbnail protocol and exposed the existing Rust
  thumbnail preparation service. Packaged Rust media helpers now receive explicit
  bundled FFmpeg/FFprobe paths instead of depending on PATH.
- Visual baselines use seeded test data and intercepted thumbnail images under
  `test-results/home-baseline/`; they validate layout, not live API results.
- Validation: typecheck/build/formatting, 63 Rust tests (3 ignored), 22 unit tests,
  4 Electron regressions, and 16 browser tests passed. Packaged Linux Home passed
  with a generated local video and real thumbnail while PATH excluded FFmpeg,
  confirming bundled-tool resolution. Live YouTube API/IFrame behavior and other
  operating systems remain unverified locally.

- Follow-up fixes: dispatch blocking Rust services through `spawn_blocking` and
  adapt Rust YouTube result shapes into thumbnail URLs and search pagination.
  The HTTP bridge regression reproduces the original runtime panic before the
  fix and passes afterward without live network access. Final checks include
  25 unit tests and 5 targeted Home/Explore browser checks, with actual image
  loading asserted against the Rust response shape.

## Step 2 implementation notes

Implemented on `feat/frontend-library`, created from the merged Home PR.
Accepted by the user on 2026-11-28 for integration into `feat/frontend-rework`.

- Matched the supplied Qt Library reference: wide content area, 220px portrait
  text/PDF covers with initial-letter artwork and type badges, 340px landscape
  video cards, progress bars and hover/focus action menus.
- Reused the old Svelte dropdown-menu and sheet interaction patterns with current
  Electron command wrappers. Import/paste, text editing, deletion and video
  removal use dialogs with keyboard/focus handling and visible operation errors.
- PDFs open in the existing reader and expose Delete, but not a text editor.
  Search matches original and display titles and distinguishes empty shelves
  from no matching results. Existing local thumbnails use the managed protocol;
  missing thumbnails are prepared serially without blocking card rendering.
- Moved library refresh/thumbnail orchestration into `lib/library/state.svelte.ts`
  and shared playback time formatting into `lib/video/time.ts`.
- Browser coverage uses mutable fixtures for paste/edit/remove/native-picker
  outcomes and verifies preserved drafts after failed saves. Captures in
  `test-results/library-baseline/` cover light/dark/narrow layouts. Video images
  in browser captures use the fallback icon; actual image loading is checked in
  the packaged Electron smoke route against a generated temporary video.
- Validation passed: typecheck, build, formatting, 25 unit tests, 20 browser tests,
  and all 11 existing packaged Linux smoke routes. The expanded Library route
  verified actual TXT/PDF imports, a generated video thumbnail, stored progress,
  and preservation of the original video after removal. Windows/macOS remain
  unverified locally. Changes are uncommitted for review.
- Follow-up: Home and Library now share `components/media/MediaHover.svelte`.
  Both use Home's 200ms artwork zoom and scale-in action badge, with a book icon
  for documents. Library menus sit above the overlay and hold it open while used.
  Typecheck/build and all 9 Home/Library browser checks passed after extraction.
- Follow-up: normalize decomposed Hangul to NFC for Library display/search without
  rewriting stored titles; use bundled Noto Sans KR and whole-word wrapping for
  card titles. The three-dot button uses a borderless, shadowless card fill.
  A decomposed-title browser regression and all 6 Library checks pass.
- Follow-up: matched Qt's 560×520 import editor: file chooser first, focused title,
  expandable Korean text area, Cancel and soft Import text actions, a borderless
  rounded card and dimmed backdrop without blur. All 7 Library browser checks
  pass, including editor autofocus/Cancel and the existing import/edit flows.
- Follow-up: unified app-wide form focus styling and removed stacked rings from
  shared inputs/buttons/sidebar controls. Text fields use a single inset accent
  edge without layout shifts; keyboard outlines and invalid-field colors remain.
  Typecheck/build/formatting, 25 unit tests and all 24 browser tests passed.

## Step 3 implementation notes

Implemented on `feat/frontend-analysis`, using the supplied Qt analysis, save
form and embedded-dictionary screenshots. Accepted by the user on 2026-11-28;
further visual polish is deferred.

- Shared Analysis/Naver/KRDict/Papago/custom tab strip, word/bookmark header,
  automatic word/lemma lookup, selectable/expandable meanings, morphology when
  meanings are unavailable, and source attribution.
- Docked save form supports edited word/meaning, tags, notes, saved-word editing
  and removal, draft retention across tabs, visible failures and offline saves.
  Reader and local Watch pass source identity to the same panel/model.
- Fixed KRDict embedded-tab support, persisted order restoration, empty-result
  fallback and inactive-frame retention. Typing in Watch's panel no longer fires
  playback shortcuts. CSP permits HTTPS custom frames without replacing the
  dictionaries' own security policies. Some sites may still require the external
  browser; local mock frames validate mechanics rather than live site support.
- Reader's full layout/resize treatment remains part of its next slice. Existing
  readers and playback remain mounted around the shared panel for this stage.
- Validation passed: typecheck with no warnings, production build, formatting,
  26 unit tests, Electron security checks, 30 browser tests and all 11 packaged
  Linux smoke routes using temporary libraries. Packaged Reader and Watch checks
  verified offline word saving with their original document/video context.
  Live embedded sites and Windows/macOS remain unverified locally.

- Follow-up: Reader and Watch use a shared right-edge sidebar below the shell
  header, with a slide-in transition and reduced-motion support. Wide windows
  reserve content space; narrow windows overlay the content. The panel no longer
  participates in the centered page's wrapping row.

## Step 4 implementation notes

Implemented on `feat/frontend-reader` using the supplied Qt Book, Scroll and
plain-text references. Awaiting user review.

- Document title and Library link live in the shell header. Text reads in a
  centered 780px column without a card or persistent word underlines, with
  Settings typography and full-height independent scrolling.
- Adapted the old TokenPassage component for visible-passage analysis. Selection
  offsets include each passage's document offset; disposed readers discard late
  replies. The shared vocabulary sidebar preserves the reading session.
- PDF Book fits the available height; Scroll uses continuous pages up to 920px
  wide. Toolbar navigation, keyboard arrows, blank-page-half turns, zoom/reset,
  page retention across mode/size changes, device-pixel-ratio canvas rendering
  and matched text layers use the existing pdf.js/native protocol.
- PDF progress uses the current page fraction in both modes so they reopen at
  the same page. Existing fractional records are interpreted as page fractions;
  older Scroll records stored scroll fractions, so their first restored page may
  differ slightly. Scanned PDFs still have no OCR/word selection.
- Validation: typecheck with no warnings, build, formatting, 26 unit tests and
  all 32 browser checks passed. Reader/shell checks passed again after guarding
  incomplete title metadata. Packaged Linux Reader/PDF checks verified real
  vocabulary saving, a stored 0.6 reading position, native PDF loading, 25 text
  spans and switching to Scroll. Browser captures use a synthetic three-page PDF
  for navigation/zoom/resize checks. Windows/macOS remain unverified locally.

## Step 5 implementation notes

Implemented on `feat/frontend-watch`, stacked on the unmerged Reader branch so
PR #49 stays unmerged. Accepted by the user for an unmerged PR on 2026-11-28;
further polish is deferred. Reference: the running
`Sori-v0.1.0-dirty-x86_64.AppImage` from the Qt checkout, with windowed/fullscreen
and subtitle-menu captures plus its Watch/Transcript/SubtitleDefinition QML.

- Matched the centered player column, overlay controls, title and transcript
  card. CC holds track selectors, subtitle visibility and attachment. Native
  Chromium playback, volume, fullscreen and guarded keyboard shortcuts remain.
- Timed transcripts have seeking timestamps, clickable Korean words, active-row
  highlights and independent scrolling/follow control. Lazy passage analysis
  avoids analyzing every subtitle before showing the selected track.
- Caption words pause playback for a compact definition/bookmark popup and can
  expand into the shared right sidebar. Transcript words open the sidebar.
  Dismissal resumes only playback that lookup itself paused; fullscreen keeps
  tools inside the fullscreen element.
- Exposed existing Rust text-transcript read/attach/position/remove services
  through the command bridge and added a TXT picker. Sidecar attachments now
  persist via the existing Rust command and restore on reopening.
- Home/Explore YouTube links use Watch with native iframe controls, cached/fetched
  captions, text transcripts and source-specific vocabulary. Live YouTube sites
  and the optional caption helper remain network-dependent; local browser tests
  use a fixture adapter. Alternate local audio-track selection is not exposed.
- Validation passed: typecheck without warnings, build, formatting, 26 unit
  tests, Electron checks, 39 browser tests, and 63 Rust tests (3 ignored).
  Native Watch smoke verifies local/YouTube text transcript persistence,
  replacement/removal, position restoration, vocabulary and saved sidecars in
  temporary libraries. All 11 packaged Linux smoke routes passed across the
  validation runs; the subtitle route was rerun after updating its harness to
  wait for lazy word analysis and expand the compact definition before saving.
  Windows/macOS and live YouTube/helper responses remain unverified locally.
