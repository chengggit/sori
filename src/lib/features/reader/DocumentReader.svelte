<script lang="ts">
  import { onDestroy, tick } from "svelte";
  import { X } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { analyzeDocumentWord, type WordAnalysis } from "./analysis";
  import { saveReadingProgress, trackReadingProgress } from "./progress";
  import TokenPassage from "./TokenPassage.svelte";
  import { readingPassages, type TokenBlock } from "./tokens";
  import WordBreakdown from "./WordBreakdown.svelte";
  import WholeWordMeaning from "./WholeWordMeaning.svelte";
  import DictionaryLookup from "../dictionary/DictionaryLookup.svelte";
  import { dictionaryForm, type DictionaryDefinition } from "../dictionary/dictionary";
  import {
    listVocabulary,
    saveVocabulary,
    removeVocabulary,
    type VocabularyEntry,
  } from "../vocabulary/vocabulary";

  let {
    document,
    reportError,
  }: {
    document: { id: number; content: string; position: number };
    reportError: (message: string) => void;
  } = $props();
  let scroller = $state<HTMLDivElement>();
  let readerWidth = $state(0);
  let sidebarWidth = $state(420);
  let resizing = $state(false);
  let dragStartX = 0;
  let dragStartWidth = 0;
  const panelId = $props.id();
  const maxSidebarWidth = $derived(Math.max(0, readerWidth - Math.min(240, readerWidth * 0.4)));
  const minSidebarWidth = $derived(Math.min(280, maxSidebarWidth));
  const panelWidth = $derived(Math.max(minSidebarWidth, Math.min(sidebarWidth, maxSidebarWidth)));
  let selection = $state<TokenBlock>();
  const passages = $derived(readingPassages(document.content));
  let analysis = $state<WordAnalysis>();
  let saved = $state<VocabularyEntry>();
  let normalized = $state("");
  let definition = $state<DictionaryDefinition | null>(null);
  let dictionaryOpen = $state(false);
  const dictionaryTerm = $derived.by(() => {
    if (!analysis) return "";
    const token = normalized
      ? analysis.morphemes.find((item) => item.form === normalized)
      : analysis.morphemes.find((item) => /^(N|VV|VA|VX)/.test(item.tag));
    return token ? dictionaryForm(token) : normalized || analysis.word;
  });
  let loading = $state(false);
  let saving = $state(false);
  let error = $state("");
  let request = 0;

  function resizeSidebar(width: number) {
    sidebarWidth = Math.max(minSidebarWidth, Math.min(width, maxSidebarWidth));
  }

  function startResize(event: PointerEvent) {
    if (event.button !== 0) return;
    const handle = event.currentTarget as HTMLDivElement;
    handle.focus();
    handle.setPointerCapture(event.pointerId);
    dragStartX = event.clientX;
    dragStartWidth = panelWidth;
    resizing = true;
    event.preventDefault();
  }

  function resizeWithKeyboard(event: KeyboardEvent) {
    switch (event.key) {
      case "ArrowLeft":
        resizeSidebar(panelWidth + 20);
        break;
      case "ArrowRight":
        resizeSidebar(panelWidth - 20);
        break;
      case "Home":
        resizeSidebar(minSidebarWidth);
        break;
      case "End":
        resizeSidebar(maxSidebarWidth);
        break;
      default:
        return;
    }
    event.preventDefault();
  }
  $effect(() => {
    if (!scroller) return;
    const element = scroller;
    const id = document.id;
    const position = document.position;
    let disposed = false;
    let stop: (() => void) | undefined;
    // Restore after the source passages have mounted.
    void tick().then(() => {
      if (!disposed)
        stop = trackReadingProgress(
          element,
          position,
          (value) => saveReadingProgress(id, value),
          reportError,
        );
    });
    return () => {
      disposed = true;
      stop?.();
    };
  });
  onDestroy(() => {
    request += 1;
  });

  function selectToken(token: TokenBlock) {
    selection = token;
    request += 1;
    analysis = undefined;
    saved = undefined;
    normalized = "";
    definition = null;
    dictionaryOpen = false;
    error = "";
    loading = true;
    void analyzeSelection();
  }

  async function analyzeSelection() {
    if (!selection) return;
    const current = ++request;
    loading = true;
    error = "";
    try {
      const [result, vocabulary] = await Promise.all([
        analyzeDocumentWord(document.id, selection.start, selection.end),
        listVocabulary(),
      ]);
      if (current !== request) return;
      analysis = result;
      saved = vocabulary.find(
        (item) =>
          item.documentId === document.id &&
          item.word === result.word &&
          item.context === result.context,
      );
      normalized = saved?.normalizedForm ?? "";
    } catch (cause) {
      if (current === request) error = String(cause);
    } finally {
      if (current === request) loading = false;
    }
  }

  async function toggleSaved() {
    if (!analysis || saving) return;
    const current = request;
    const entry = saved;
    saving = true;
    error = "";
    try {
      if (entry) {
        await removeVocabulary(entry.id);
        if (current === request) saved = undefined;
      } else {
        const result = await saveVocabulary({
          documentId: document.id,
          word: analysis.word,
          context: analysis.context,
          normalizedForm: normalized || null,
          definition,
        });
        if (current === request) saved = result;
      }
    } catch (cause) {
      if (current === request) error = String(cause);
    } finally {
      saving = false;
    }
  }

  function dismiss() {
    request += 1;
    selection = undefined;
    analysis = undefined;
    error = "";
  }
</script>

<div bind:clientWidth={readerWidth} class="flex min-h-0 min-w-0 flex-1" class:select-none={resizing}>
  <!-- svelte-ignore a11y_no_noninteractive_tabindex (The scrollable reader supports keyboard scrolling.) -->
  <div
    bind:this={scroller}
    class="min-h-0 min-w-0 flex-1 overflow-y-auto px-4 pt-5 pb-8 sm:px-6"
    tabindex="0"
    role="region"
    aria-label="Document text"
  >
    <div lang="ko" class="mx-auto max-w-3xl text-lg leading-10 wrap-break-word whitespace-pre-wrap">
      {#each passages as passage (passage.start)}<TokenPassage
          text={passage.text}
          start={passage.start}
          root={scroller}
          selectedStart={selection?.start}
          onToken={selectToken}
        />{/each}
    </div>
  </div>
  {#if selection}
    <aside
      id={panelId}
      aria-label="Word analysis"
      style:width={`${panelWidth}px`}
      class="relative min-w-0 shrink-0 border-l bg-popover"
    >
      <!-- svelte-ignore a11y_no_noninteractive_tabindex, a11y_no_noninteractive_element_interactions (A focusable window splitter uses the ARIA separator role and supports arrow keys.) -->
      <div
        role="separator"
        tabindex="0"
        aria-label="Resize word analysis"
        aria-orientation="vertical"
        aria-controls={panelId}
        aria-valuemin={Math.round(minSidebarWidth)}
        aria-valuemax={Math.round(maxSidebarWidth)}
        aria-valuenow={Math.round(panelWidth)}
        class="absolute inset-y-0 -left-1 z-10 w-2 cursor-col-resize touch-none hover:bg-primary/20 focus-visible:bg-primary/20 focus-visible:outline-2 focus-visible:outline-ring"
        onpointerdown={startResize}
        onpointermove={(event) => {
          if (resizing) resizeSidebar(dragStartWidth + dragStartX - event.clientX);
        }}
        onpointerup={(event) => {
          const handle = event.currentTarget as HTMLDivElement;
          if (handle.hasPointerCapture(event.pointerId)) handle.releasePointerCapture(event.pointerId);
          resizing = false;
        }}
        onlostpointercapture={() => (resizing = false)}
        onkeydown={resizeWithKeyboard}
      ></div>
      <div class="h-full overflow-y-auto px-4 pt-3 pb-6 sm:px-5">
        <Button
          variant="ghost"
          size="icon-sm"
          aria-label="Close word analysis"
          class="absolute top-2 right-2 z-10"
          onclick={dismiss}><X /></Button
        >
        <h2 lang="ko" class="mb-4 pr-9 text-xl font-semibold wrap-break-word">{selection.text}</h2>
        {#if loading}
          <p role="status" class="text-sm text-muted-foreground">Analyzing…</p>
        {:else if analysis}
          <WholeWordMeaning
            word={analysis.word}
            tokens={analysis.morphemes}
            selected={saved?.definition ?? definition}
            savedDefinition={saved?.definition}
            locked={saving || !!saved}
            onSelect={(value) => (definition = value)}
          />
          <WordBreakdown
            tokens={analysis.morphemes}
            selected={saved?.definition ?? definition}
            savedDefinition={saved?.definition}
            locked={saving || !!saved}
            onSelect={(value) => (definition = value)}
          />
          {#if definition && !saved}
            <p class="mb-3 text-xs text-muted-foreground">
              Meaning selected for saving · {definition.term}
            </p>
          {/if}
          <details bind:open={dictionaryOpen} class="my-4 border-y py-3">
            <summary class="cursor-pointer text-sm font-medium"
              >{saved?.definition ? "Saved meaning" : "Search dictionary"}</summary
            >
            {#if dictionaryOpen}
              <DictionaryLookup
                term={dictionaryTerm}
                savedDefinition={saved?.definition}
                locked={saving || !!saved}
                onSelect={(value) => (definition = value)}
              />
            {/if}
          </details>
          <div class="flex flex-wrap items-end gap-3">
            <label class="grid gap-1 text-xs text-muted-foreground">
              Morpheme to collect (optional)
              <select
                bind:value={normalized}
                disabled={saving || !!saved}
                class="h-8 rounded-md border bg-background px-2 text-sm text-foreground"
              >
                <option value="">Original word</option>
                {#each [...new Set(analysis.morphemes.map((token) => token.form))] as form}<option
                    value={form}>{form}</option
                  >{/each}
              </select>
            </label>
            <Button
              size="sm"
              variant={saved ? "outline" : "default"}
              disabled={saving}
              onclick={toggleSaved}
              >{saving ? "Saving…" : saved ? "Remove saved word" : "Save word"}</Button
            >
            {#if saved}<span role="status" class="text-sm text-muted-foreground">Saved</span>{/if}
          </div>
        {/if}
        {#if error}
          <p role="alert" class="mt-2 text-sm text-destructive">{error}</p>
          {#if !analysis}<Button size="sm" variant="outline" class="mt-2" onclick={analyzeSelection}
              >Retry analysis</Button
            >{/if}
        {/if}
      </div>
    </aside>
  {/if}
</div>
