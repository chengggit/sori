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

- [ ] **1. Home — `feat/frontend-home`**
      Start from old `src/routes/+page.svelte`: dashboard layout, resume cards,
      YouTube link entry and discovery/search presentation. Use Rust-backed state
      and current YouTube commands; no renderer API key or duplicate local history.
      Reuse the existing working YouTube playback destination until the Watch slice
      provides a shared destination. Handle offline and missing-key states honestly.
      **Done when:** Home is populated by real library/history data, empty libraries
      have useful actions, resume links open the correct item, and optional online
      controls show loading/errors without blocking offline use.

- [ ] **2. Library — `feat/frontend-library`**
      Start from old `src/routes/library/+page.svelte`: document/video shelves,
      search, import sheet, item actions, edit and remove flows. Keep current native
      file pickers, paste import, TXT/PDF support and Rust-owned metadata/progress.
      **Done when:** import, paste, search, edit, open and remove work on real sample
      data; PDF and video items retain their current capabilities; mutations refresh
      the page and removing an item preserves the original user media files.

- [ ] **3. Analysis and dictionary panels — `feat/frontend-analysis`**
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
      Existing sidecar persistence gaps remain tracked in the migration backlog.

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
Step 0 is complete; integration into `feat/frontend-rework` is pending.

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
