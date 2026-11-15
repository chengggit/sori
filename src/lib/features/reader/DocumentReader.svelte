<script lang="ts">
  import { onDestroy, tick } from "svelte";
  import { Bookmark, X } from "@lucide/svelte";
  import { Tabs } from "bits-ui";
  import { openUrl } from "@tauri-apps/plugin-opener";
  import { Button } from "$lib/components/ui/button";
  import { analyzeDocumentWord, type WordAnalysis } from "./analysis";
  import { saveReadingProgress, trackReadingProgress } from "./progress";
  import TokenPassage from "./TokenPassage.svelte";
  import { readingPassages, type TokenBlock } from "./tokens";
  import WordBreakdown from "./WordBreakdown.svelte";
  import { wordBreakdown } from "./breakdown";
  import WholeWordMeaning from "./WholeWordMeaning.svelte";
  import SaveWordPanel from "./SaveWordPanel.svelte";
  import EmbeddedLookup from "../dictionary/EmbeddedLookup.svelte";
  import { embeddedProviders } from "../dictionary/embedded";
  import { embedSettings } from "../dictionary/embed-settings";
  import {
    dictionaryLicense,
    type DictionaryDefinition,
  } from "../dictionary/dictionary";
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
  let sidebarWidth = $state(500);
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
  let definition = $state<DictionaryDefinition | null>(null);
  let suggestedMeaning = $state<DictionaryDefinition | null>(null);
  let savePanelOpen = $state(false);
  let draftSource = $state<DictionaryDefinition | null>(null);
  let saveTrigger: HTMLButtonElement | undefined;

  function openSavePanel(event: MouseEvent) {
    saveTrigger = event.currentTarget as HTMLButtonElement;
    draftSource = saved?.definition ?? definition ?? suggestedMeaning;
    error = "";
    savePanelOpen = true;
  }

  function closeSavePanel() {
    savePanelOpen = false;
    saveTrigger?.focus();
  }
  let sources = $state<Record<string, string>>({});
  let lookupView = $state("analysis");
  let visitedLookupViews = $state(new Set<string>());
  const enabledProviders = $derived([
    ...embeddedProviders.map((provider) => ({ ...provider, provider: provider.value, url: "" })),
    ...$embedSettings.custom.map((item) => ({ value: item.id, label: new URL(item.url).hostname, provider: "custom" as const, url: item.url })),
  ].filter((provider) => $embedSettings.enabled.includes(provider.value)));
  $effect(() => {
    if (lookupView !== "analysis" && !enabledProviders.some((provider) => provider.value === lookupView)) lookupView = "analysis";
  });

  function selectLookupView(value: string) {
    lookupView = value;
    visitedLookupViews = new Set([...visitedLookupViews, value]);
  }

  function collectSources(definitions: DictionaryDefinition[]) {
    sources = {
      ...sources,
      ...Object.fromEntries(definitions.filter((item) => item.sourceUrl).map((item) => [item.term, item.sourceUrl])),
    };
  }

  async function openSource(url: string) {
    try {
      await openUrl(url);
    } catch (cause) {
      error = String(cause);
    }
  }
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
    definition = null;
    suggestedMeaning = null;
    savePanelOpen = false;
    draftSource = null;
    sources = {};
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
      if (saved?.definition) collectSources([saved.definition]);
    } catch (cause) {
      if (current === request) error = String(cause);
    } finally {
      if (current === request) loading = false;
    }
  }

  async function saveWord(draft: { word: string; meaning: string; note: string; tags: string[] }) {
    if (!analysis || saving) return;
    const current = request;
    saving = true;
    error = "";
    try {
      if (!draft.word || !draft.meaning) {
        error = "Enter a word and meaning before saving.";
        return;
      }
      const meaning = {
        term: draftSource?.term ?? draft.word,
        partOfSpeech: draftSource?.partOfSpeech ?? "",
        sourceUrl: draftSource?.sourceUrl ?? "",
        hanja: draftSource?.hanja ?? null,
        text: draft.meaning,
        custom: draftSource?.custom || !draftSource || draft.meaning !== draftSource.text,
        note: draft.note || null,
      };
      const result = await saveVocabulary({
        documentId: document.id,
        word: analysis.word,
        context: analysis.context,
        normalizedForm: draft.word === analysis.word ? null : draft.word,
        definition: meaning,
        tags: draft.tags,
      });
      if (current === request) {
        saved = result;
        definition = meaning;
        closeSavePanel();
      }
    } catch (cause) {
      if (current === request) error = String(cause);
    } finally {
      saving = false;
    }
  }

  async function removeSavedWord() {
    if (!saved || saving) return;
    const current = request;
    saving = true;
    error = "";
    try {
      await removeVocabulary(saved.id);
      if (current === request) {
        saved = undefined;
        closeSavePanel();
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
      <div class="flex h-full min-h-0 flex-col">
        <Button
          variant="ghost"
          size="icon-sm"
          aria-label="Close word analysis"
          class="absolute top-2 right-2 z-10"
          onclick={dismiss}><X /></Button
        >
        <Tabs.Root
          value={lookupView}
          onValueChange={selectLookupView}
          class="flex min-h-0 flex-1 flex-col"
        >
          <Tabs.List
            aria-label="Lookup views"
            class="flex shrink-0 gap-1 overflow-x-auto border-b bg-muted/50 px-3 pt-1 pr-10"
          >
            {#each [{ value: "analysis", label: "Analysis" }, ...enabledProviders] as tab}
              <Tabs.Trigger
                value={tab.value}
                class="relative -mb-px min-w-0 flex-1 truncate rounded-t-lg border border-transparent px-3 py-2 text-sm text-muted-foreground hover:bg-accent focus-visible:z-10 focus-visible:outline-2 focus-visible:outline-ring data-[state=active]:border-border data-[state=active]:border-b-popover data-[state=active]:bg-popover data-[state=active]:font-medium data-[state=active]:text-foreground"
              >
                {tab.label}
              </Tabs.Trigger>
            {/each}
          </Tabs.List>
          <div class="my-3 flex shrink-0 items-center gap-2 px-4 sm:px-5">
            <h2 lang="ko" class="min-w-0 text-xl font-semibold wrap-break-word">{selection.text}</h2>
            <button type="button" aria-label={saved ? "View saved word" : "Save this word"} title={saved ? "View saved word" : "Save word"} aria-expanded={savePanelOpen} disabled={!analysis || saving} class="shrink-0 rounded-md p-1.5 hover:bg-accent focus-visible:outline-2 focus-visible:outline-ring disabled:opacity-50" onclick={openSavePanel}>
              <Bookmark class="size-5" fill={saved ? "currentColor" : "none"} />
            </button>
          </div>
          {#each enabledProviders as item}
            <Tabs.Content
              value={item.value}
              class="flex min-h-0 flex-1 flex-col pt-3 data-[state=inactive]:hidden"
            >
              {#if visitedLookupViews.has(item.value)}
                <EmbeddedLookup provider={item.provider} customUrl={item.url} label={item.label} word={selection.text} />
              {/if}
            </Tabs.Content>
          {/each}
          <Tabs.Content
            value="analysis"
            class="min-h-0 flex-1 overflow-y-auto px-4 pt-3 pb-6 data-[state=inactive]:hidden sm:px-5"
          >
            {#if lookupView === "analysis"}
              {#if loading}
                <p role="status" class="text-sm text-muted-foreground">Analyzing…</p>
              {:else if analysis}
                <WholeWordMeaning
                  onSources={(definitions) => {
                    collectSources(definitions);
                    suggestedMeaning = definitions[0] ?? null;
                  }}
                  word={analysis.word}
                  tokens={analysis.morphemes}
                  selected={saved?.definition ?? definition}
                  savedDefinition={saved?.definition}
                  locked={saving || !!saved || savePanelOpen}
                  onSelect={(value) => (definition = value)}
                />
                {#if wordBreakdown(analysis.morphemes).length > 1}
                  <WordBreakdown
                    onSources={collectSources}
                    tokens={analysis.morphemes}
                    selected={saved?.definition ?? definition}
                    savedDefinition={saved?.definition}
                    savedWord={saved?.normalizedForm ?? saved?.word}
                    locked={saving || !!saved || savePanelOpen}
                    onSelect={(value) => (definition = value)}
                  />
                {/if}
              {/if}
              {#if error && !savePanelOpen}
                <p role="alert" class="mt-2 text-sm text-destructive">{error}</p>
                {#if !analysis}<Button
                    size="sm"
                    variant="outline"
                    class="mt-2"
                    onclick={analyzeSelection}>Retry analysis</Button
                  >{/if}
              {/if}
            {/if}
          </Tabs.Content>
          {#if lookupView === "analysis" && Object.keys(sources).length}
            <footer class="max-h-[30%] shrink-0 overflow-y-auto border-t px-4 py-3 sm:px-5">
              <details class="text-xs text-muted-foreground">
                <summary class="cursor-pointer">Sources</summary>
                <p class="mt-2">Definitions by Wiktionary contributors. Formatting removed.</p>
                <button
                  type="button"
                  class="mt-1 underline"
                  onclick={() => openSource(dictionaryLicense)}>CC BY-SA 4.0</button
                >
                <ul class="mt-2 space-y-1">
                  {#each Object.entries(sources) as [term, url]}
                    <li>
                      <button
                        type="button"
                        lang="ko"
                        class="underline"
                        onclick={() => openSource(url)}>{term}</button
                      >
                    </li>
                  {/each}
                </ul>
              </details>
            </footer>
          {/if}
        </Tabs.Root>
      </div>
      {#if savePanelOpen && analysis}
        <SaveWordPanel word={analysis.word} definition={draftSource} {saved} {saving} {error} onSave={saveWord} onRemove={removeSavedWord} onClose={closeSavePanel} />
      {/if}
    </aside>
  {/if}
</div>
