<script lang="ts">
  import { Captions, ExternalLink } from "@lucide/svelte";
  import { isTauri } from "@tauri-apps/api/core";
  import { Button } from "$lib/components/ui/button";
  import { dictionaryLicense, type DictionaryDefinition } from "../dictionary/dictionary";
  import {
    findVideoVocabulary,
    removeVocabulary,
    saveVideoVocabulary,
    type VideoVocabularySource,
    type VocabularyEntry,
  } from "../vocabulary/vocabulary";
  import SaveWordPanel from "../reader/SaveWordPanel.svelte";
  import WholeWordMeaning from "../reader/WholeWordMeaning.svelte";
  import WordBreakdown from "../reader/WordBreakdown.svelte";
  import TokenPassage from "../reader/TokenPassage.svelte";
  import type { TokenBlock } from "../reader/tokens";
  import LocalPlayer from "./LocalPlayer.svelte";
  import RemuxPlayer from "./RemuxPlayer.svelte";
  import YouTubePlayer from "./YouTubePlayer.svelte";
  import { readVideoSubtitles, saveVideoSidecar, type LocalVideoDetails } from "./local";
  import { activeSubtitleCues, parseSubtitles, type SubtitleCue } from "./subtitles";
  import type { PlaybackControls, PlaybackEvents } from "./playback";

  let {
    source,
    title,
    start,
    onSaveProgress,
  }: {
    source: { kind: "local"; video: LocalVideoDetails } | { kind: "youtube"; id: string };
    title: string;
    start: number;
    onSaveProgress: PlaybackEvents["onSave"];
  } = $props();

  let seconds = $state(0);
  let localMode = $state<"webview" | "remux">("webview");
  let playerStart = $state<number>();
  let controls: PlaybackControls | undefined;
  const events: PlaybackEvents = {
    onTime: (position) => {
      seconds = position;
    },
    onSave: (position, duration, completed) => onSaveProgress(position, duration, completed),
    onControls: (player) => {
      controls = player;
    },
  };
  let embedded = $state<SubtitleCue[]>([]);
  let sidecar = $state<SubtitleCue[]>([]);
  let track = $state("off");
  let trackError = $state("");
  let loading = $state(false);
  let importing = $state(false);
  let trackRequest = 0;
  let subtitleRoot = $state<HTMLDivElement>();
  let selection = $state<{ cue: SubtitleCue; token: TokenBlock }>();
  let suggested = $state<DictionaryDefinition | null>(null);
  let chosen = $state<DictionaryDefinition | null>(null);
  let sources = $state<Record<string, string>>({});
  let panelOpen = $state(false);
  let saving = $state(false);
  let saveError = $state("");
  let saved = $state<VocabularyEntry>();
  let checkingSaved = $state(false);

  const tracks = $derived(source.kind === "local" ? source.video.tracks : []);
  const vocabularySource: VideoVocabularySource = $derived(
    source.kind === "local"
      ? { kind: "local", id: source.video.id }
      : { kind: "youtube", id: source.id, title },
  );
  const active = $derived(
    activeSubtitleCues(track === "sidecar" ? sidecar : track === "off" ? [] : embedded, seconds),
  );

  $effect(() => {
    if (source.kind !== "local") return;
    const { sidecar: storedSidecar, tracks } = source.video;
    const storedCues = storedSidecar ? parseSubtitles(storedSidecar) : [];
    sidecar = storedCues;
    const available = tracks.filter((item) => item.text);
    const preferred =
      available.find((item) => /^(ko|kor)(-|$)/i.test(item.language ?? "")) ?? available[0];
    void selectTrack(storedCues.length ? "sidecar" : preferred ? String(preferred.index) : "off");
  });

  async function selectTrack(value: string) {
    const request = ++trackRequest;
    track = value;
    trackError = "";
    embedded = [];
    loading = false;
    selection = undefined;
    if (value === "off" || value === "sidecar" || source.kind !== "local") return;
    loading = true;
    try {
      const result = await readVideoSubtitles(source.video.id, Number(value));
      if (request !== trackRequest) return;
      embedded = parseSubtitles(result);
      if (!embedded.length) trackError = "This track contains no readable subtitle cues.";
    } catch (cause) {
      if (request === trackRequest) trackError = String(cause);
    } finally {
      if (request === trackRequest) loading = false;
    }
  }

  async function attachSubtitle(event: Event & { currentTarget: HTMLInputElement }) {
    const file = event.currentTarget.files?.[0];
    event.currentTarget.value = "";
    if (!file) return;
    importing = true;
    trackError = "";
    try {
      if (file.size > 8 * 1024 * 1024) throw new Error("The subtitle file exceeds 8 MiB.");
      const text = new TextDecoder("utf-8", { fatal: true }).decode(await file.arrayBuffer());
      const cues = parseSubtitles(text);
      if (!cues.length) throw new Error("Choose a UTF-8 SRT or WebVTT file with timed subtitles.");
      if (source.kind === "local") await saveVideoSidecar(source.video.id, text);
      sidecar = cues;
      await selectTrack("sidecar");
    } catch (cause) {
      trackError = String(cause);
    } finally {
      importing = false;
    }
  }

  async function selectWord(cue: SubtitleCue, token: TokenBlock) {
    controls?.pause();
    selection = { cue, token };
    const current = selection;
    chosen = null;
    suggested = null;
    sources = {};
    saved = undefined;
    panelOpen = false;
    saveError = "";
    checkingSaved = true;
    try {
      const result = await findVideoVocabulary(vocabularySource, token.text, cue.text);
      if (selection === current) saved = result ?? undefined;
    } catch (cause) {
      if (selection === current) saveError = String(cause);
    } finally {
      if (selection === current) checkingSaved = false;
    }
  }

  function collectSources(definitions: DictionaryDefinition[]) {
    for (const { term, sourceUrl } of definitions) {
      if (sourceUrl) sources[term] = sourceUrl;
    }
  }

  async function saveWord(draft: { word: string; meaning: string; note: string; tags: string[] }) {
    if (!selection || saving) return;
    const current = selection;
    const definition = chosen ?? suggested;
    saving = true;
    saveError = "";
    try {
      const result = await saveVideoVocabulary({
        source: vocabularySource,
        word: selection.token.text,
        normalizedForm: draft.word,
        context: selection.cue.text,
        tags: draft.tags,
        definition: {
          term: definition?.term ?? draft.word,
          partOfSpeech: definition?.partOfSpeech ?? "",
          text: draft.meaning,
          sourceUrl: definition?.sourceUrl ?? "",
          hanja: definition?.hanja,
          custom: !definition || definition.custom || draft.meaning !== definition.text,
          note: draft.note || null,
        },
      });
      if (selection === current) {
        saved = result;
        panelOpen = false;
        saveError = "";
      }
    } catch (cause) {
      if (selection === current) saveError = String(cause);
    } finally {
      saving = false;
    }
  }

  async function removeWord() {
    if (!saved || saving) return;
    const current = selection;
    saving = true;
    saveError = "";
    try {
      await removeVocabulary(saved.id);
      if (selection === current) {
        saved = undefined;
        panelOpen = false;
      }
    } catch (cause) {
      if (selection === current) saveError = String(cause);
    } finally {
      saving = false;
    }
  }
</script>

<div class="relative" bind:this={subtitleRoot}>
  {#if source.kind === "local" && localMode === "remux"}
    <RemuxPlayer id={source.video.id} {title} start={playerStart ?? start} {events} />
  {:else if source.kind === "local"}
    <LocalPlayer
      path={source.video.path}
      playbackUrl={source.video.playbackUrl}
      {title}
      start={playerStart ?? start}
      {events}
    />
  {:else}
    <YouTubePlayer id={source.id} {title} {start} {events} />
  {/if}
  {#if active.length}
    <div
      class="pointer-events-none absolute inset-x-2 bottom-16 grid justify-items-center gap-1"
    >
      {#each active as cue (cue)}
        <div
          class="pointer-events-auto max-w-full rounded-md bg-black/80 px-3 py-1 text-center text-base wrap-anywhere whitespace-pre-wrap text-white sm:text-xl"
          lang="ko"
        >
          {#if isTauri()}
            <TokenPassage
              text={cue.text}
              start={0}
              root={subtitleRoot}
              selectedStart={selection?.cue === cue ? selection.token.start : undefined}
              onToken={(token) => selectWord(cue, token)}
            />
          {:else}
            {cue.text}
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<div class="mt-4 flex flex-wrap items-start justify-between gap-3">
  <h1 class="min-w-0 flex-1 text-xl leading-snug font-semibold wrap-break-word">{title}</h1>
  {#if source.kind === "local" && source.video.playbackUrl}
    <Button
      variant="outline"
      size="sm"
      onclick={() => {
        playerStart = seconds || start;
        localMode = localMode === "remux" ? "webview" : "remux";
      }}
    >
      {localMode === "remux" ? "Use webview player" : "Try MP4 streaming (experimental)"}
    </Button>
  {/if}
  {#if source.kind === "youtube"}
    <Button
      href={`https://www.youtube.com/watch?v=${source.id}`}
      target="_blank"
      rel="noopener"
      variant="outline"
      size="sm">Open on YouTube <ExternalLink /></Button
    >
  {/if}
</div>

<section aria-label="Subtitles" class="mt-6 rounded-xl border bg-card p-4 sm:p-5">
  <div class="flex flex-wrap items-center gap-3">
    <label class="flex items-center gap-2 text-sm font-medium">
      <Captions class="size-4" /> Subtitles
      <select
        class="rounded-md border bg-background px-2 py-1"
        value={track}
        onchange={(event) => selectTrack(event.currentTarget.value)}
        disabled={importing}
      >
        <option value="off">Off</option>
        {#each tracks as item (item.index)}
          <option value={String(item.index)} disabled={!item.text}>
            {item.title || item.language || `Track ${item.index}`}{item.title && item.language
              ? ` (${item.language})`
              : ""}{item.text ? "" : " — image subtitles"}
          </option>
        {/each}
        {#if sidecar.length}<option value="sidecar">Attached subtitles</option>{/if}
      </select>
    </label>
    <label class="text-sm">
      <span class="sr-only">Attach SRT or WebVTT subtitles</span>
      <input
        type="file"
        accept=".srt,.vtt"
        disabled={importing}
        onchange={attachSubtitle}
        class="max-w-full text-muted-foreground file:mr-2 file:rounded-md file:border file:bg-background file:px-2 file:py-1 file:text-foreground"
      />
    </label>
  </div>
  {#if loading || importing}
    <p class="mt-2 text-sm text-muted-foreground" role="status">Loading subtitles…</p>
  {/if}
  {#if trackError}
    <p class="mt-2 text-sm text-destructive" role="alert">{trackError}</p>
  {/if}
  {#if source.kind === "local" && source.video.probeError}
    <p class="mt-2 text-sm text-muted-foreground">{source.video.probeError}</p>
  {:else if source.kind === "youtube" && track === "off"}
    <p class="mt-2 text-sm text-muted-foreground">
      Use the YouTube player’s CC button for its captions, or attach subtitles to select words in Sori.
    </p>
  {/if}
</section>

{#if selection}
  {#key selection}
    <section aria-label="Subtitle word analysis" class="mt-4 rounded-xl border bg-card p-4 sm:p-5">
      <div class="mb-3 flex items-center justify-between gap-2">
        <h2 class="font-semibold" lang="ko">{selection.token.text}</h2>
        <Button
          size="sm"
          onclick={() => (panelOpen = true)}
          disabled={panelOpen || saving || checkingSaved}
        >
          {saved ? "View saved word" : "Save word"}
        </Button>
      </div>
      <WholeWordMeaning
        word={selection.token.text}
        tokens={selection.token.morphemes}
        selected={saved?.definition ?? chosen}
        savedDefinition={saved?.definition}
        locked={!!saved || panelOpen || saving}
        onSelect={(value) => (chosen = value)}
        onSources={(definitions) => {
          suggested = definitions[0] ?? null;
          collectSources(definitions);
        }}
      />
      {#if selection.token.morphemes.length > 1}
        <WordBreakdown
          tokens={selection.token.morphemes}
          selected={saved?.definition ?? chosen}
          locked={!!saved || panelOpen || saving}
          savedDefinition={saved?.definition}
          savedWord={saved?.normalizedForm ?? saved?.word}
          onSelect={(value) => (chosen = value)}
          onSources={collectSources}
        />
      {/if}
      {#if panelOpen}
        <SaveWordPanel
          inline
          word={selection.token.text}
          definition={chosen ?? suggested}
          {saved}
          {saving}
          error={saveError}
          onSave={saveWord}
          onRemove={removeWord}
          onClose={() => (panelOpen = false)}
        />
      {:else if saveError}
        <p class="text-sm text-destructive" role="alert">{saveError}</p>
      {/if}
      {#if Object.keys(sources).length || saved?.definition?.sourceUrl}
        <details class="mt-3 text-xs text-muted-foreground">
          <summary class="cursor-pointer">Sources</summary>
          <p class="mt-2">
            Definitions by Wiktionary contributors.
            <a class="underline" href={dictionaryLicense} target="_blank" rel="noreferrer"
              >CC BY-SA 4.0</a
            >
          </p>
          <ul class="mt-2 space-y-1">
            {#each Object.entries( { ...sources, ...(saved?.definition?.sourceUrl ? { [saved.definition.term]: saved.definition.sourceUrl } : {}) } ) as [term, url] (term)}
              <li>
                <a class="underline" href={url} target="_blank" rel="noreferrer" lang="ko">{term}</a>
              </li>
            {/each}
          </ul>
        </details>
      {/if}
    </section>
  {/key}
{/if}
