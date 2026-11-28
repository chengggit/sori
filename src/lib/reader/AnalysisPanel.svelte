<script lang="ts">
  import { Bookmark, X } from "@lucide/svelte";
  import { onMount, onDestroy, tick } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import { normalizeDisplayText } from "$lib/text";
  import type { Analysis } from "./analysis";
  import { wordBreakdown, wholeWordTerms } from "./breakdown";
  import { partOfSpeechLabel } from "./tokens";
  import { AnalysisModel, type WordSource, type WordDraft } from "$lib/analysis/state.svelte";
  import SaveWordPanel from "$lib/analysis/SaveWordPanel.svelte";
  import DictionaryPanel from "$lib/dictionary/DictionaryPanel.svelte";
  import { embedSettings, loadEmbedSettings } from "$lib/dictionary/embed-settings";
  import {
    embeddedLookupUrl,
    embeddedProviders,
    type EmbeddedProvider,
  } from "$lib/dictionary/embedded";
  import { openExternal } from "$lib/dictionary/lookup";

  let {
    analysis,
    source,
    onClose,
    docked = false,
  }: { analysis: Analysis; source?: WordSource; onClose?: () => void; docked?: boolean } = $props();
  const model = new AnalysisModel();
  let panel: HTMLElement | null = $state(null);
  let activeTab = $state("analysis");
  let frames = $state<string[]>([]);
  let frameErrors = $state<Record<string, string>>({});
  let editing = $state(false);
  let draft = $state<WordDraft>({ word: "", meaning: "", note: "", tags: [] });
  let dragged = $state<string | null>(null);
  let bookmark: HTMLButtonElement | null = $state(null);
  const timers = new Map<string, ReturnType<typeof setTimeout>>();
  const parts = $derived(wordBreakdown(analysis.tokens));
  const terms = $derived(analysis.lookupTerms ?? wholeWordTerms(analysis.word, analysis.tokens));
  const sources = $derived([
    ...new Set(
      [...model.definitions, ...(model.saved?.definition ? [model.saved.definition] : [])]
        .map((definition) => definition.sourceUrl)
        .filter((url) => url.startsWith("https://")),
    ),
  ]);
  const displayedDefinitions = $derived(
    model.definitions.length
      ? model.definitions
      : model.saved?.definition
        ? [model.saved.definition]
        : [],
  );

  $effect(() => {
    model.start(analysis, source);
    editing = false;
  });
  $effect(() => {
    if (activeTab !== "analysis" && !$embedSettings.enabled.includes(activeTab)) activeTab = "analysis";
  });
  onMount(() => loadEmbedSettings());
  onDestroy(() => {
    model.destroy();
    for (const timer of timers.values()) clearTimeout(timer);
  });
  function label(id: string) {
    return (
      embeddedProviders.find((entry) => entry.value === id)?.label ??
      (() => {
        const custom = $embedSettings.custom.find((entry) => entry.id === id);
        return custom ? new URL(custom.url).hostname : id;
      })()
    );
  }
  function url(id: string) {
    const custom = $embedSettings.custom.find((entry) => entry.id === id);
    return embeddedLookupUrl(custom ? "custom" : (id as EmbeddedProvider), analysis.word, custom?.url);
  }
  function showTab(id: string) {
    for (const timer of timers.values()) clearTimeout(timer);
    timers.clear();
    activeTab = id;
    if (id !== "analysis" && !frames.includes(id)) frames = [...frames, id];
    for (const key of frames)
      if (key !== id)
        timers.set(
          key,
          setTimeout(() => {
            frames = frames.filter((entry) => entry !== key);
            timers.delete(key);
          }, 30_000),
        );
  }
  function reorder(from: string, to: string) {
    const enabled = [...$embedSettings.enabled];
    const start = enabled.indexOf(from),
      end = enabled.indexOf(to);
    if (start < 0 || end < 0 || start === end) return;
    enabled.splice(start, 1);
    enabled.splice(end, 0, from);
    embedSettings.update((value) => ({ ...value, enabled }));
    dragged = null;
  }
  async function tabKey(event: KeyboardEvent, id: string) {
    const ids = ["analysis", ...$embedSettings.enabled];
    const index = ids.indexOf(id);
    if (event.altKey && id !== "analysis" && ["ArrowLeft", "ArrowRight"].includes(event.key)) {
      event.preventDefault();
      const to = ids[index + (event.key === "ArrowRight" ? 1 : -1)];
      if (to && to !== "analysis") reorder(id, to);
      return;
    }
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
    event.preventDefault();
    const next =
      event.key === "Home"
        ? ids[0]
        : event.key === "End"
          ? ids.at(-1)!
          : ids[(index + (event.key === "ArrowRight" ? 1 : ids.length - 1)) % ids.length];
    showTab(next);
    await tick();
    document.getElementById(`analysis-tab-${next}`)?.focus();
  }
  function openEditor() {
    const saved = model.saved;
    const definition = saved?.definition ?? model.selected;
    draft = {
      word: normalizeDisplayText(
        saved?.normalizedForm || definition?.term || terms[1] || analysis.word,
      ),
      meaning: definition?.text ?? "",
      note: definition?.note ?? "",
      tags: saved?.tags ?? [],
    };
    model.saveError = "";
    editing = true;
  }
  function closeEditor() {
    editing = false;
    void tick().then(() => bookmark?.focus());
  }
  function onKey(event: KeyboardEvent) {
    if (event.key !== "Escape" || model.saving) return;
    if (editing) {
      event.preventDefault();
      event.stopPropagation();
      closeEditor();
    } else if (onClose) {
      event.preventDefault();
      event.stopPropagation();
      onClose();
    }
  }
</script>

<svelte:window
  onkeydown={(event) => {
    if (panel?.contains(document.activeElement)) onKey(event);
  }}
/>
<section
  bind:this={panel}
  class="analysis"
  class:docked
  aria-label="Word analysis"
  data-testid="analysis-panel"
>
  <div class="tabs-row">
    <div role="tablist" aria-label="Word tools" class="tabs">
      {#each ["analysis", ...$embedSettings.enabled] as id (id)}
        <button
          type="button"
          role="tab"
          id={`analysis-tab-${id}`}
          aria-controls={`analysis-pane-${id}`}
          aria-selected={activeTab === id}
          tabindex={activeTab === id ? 0 : -1}
          class:active={activeTab === id}
          draggable={id !== "analysis"}
          ondragstart={() => (dragged = id)}
          ondragover={(event) => event.preventDefault()}
          ondrop={() => {
            if (dragged) reorder(dragged, id);
          }}
          onkeydown={(event) => tabKey(event, id)}
          onclick={() => showTab(id)}
          data-testid={id === "analysis" ? "analysis-tab" : `embed-tab-${id}`}
          title={id === "analysis" ? "Analysis" : `${label(id)} · Drag or Alt+Arrow keys to reorder`}
        >
          {id === "analysis" ? "Analysis" : label(id)}
        </button>
      {/each}
    </div>
    {#if onClose}<Button
        variant="ghost"
        size="icon-sm"
        class="shrink-0"
        aria-label="Close analysis"
        onclick={onClose}
      >
        <X size={16} />
      </Button>{/if}
  </div>
  <header class="word-header">
    <h2 lang="ko">{normalizeDisplayText(analysis.word)}</h2>
    <Button
      bind:ref={bookmark}
      variant="ghost"
      size="icon-sm"
      aria-label={editing ? "Close word editor" : model.saved ? "Edit saved word" : "Save word"}
      aria-pressed={!!model.saved}
      disabled={!source}
      title={source ? "Save word" : "Open a document or video to save vocabulary"}
      onclick={() => (editing ? closeEditor() : openEditor())}
    >
      <Bookmark size={19} fill={model.saved ? "currentColor" : "none"} />
    </Button>
  </header>
  <div class="body">
    <div
      id="analysis-pane-analysis"
      role="tabpanel"
      aria-labelledby="analysis-tab-analysis"
      hidden={activeTab !== "analysis"}
      class="analysis-body"
    >
      {#if model.loading}<p role="status" class="mb-3 text-xs text-muted-foreground">
          Looking up…
        </p>{/if}
      {#if model.error}<p
          role="alert"
          data-testid="dictionary-error"
          class="mb-3 text-sm text-destructive"
        >
          {model.error} <button class="underline" onclick={() => model.lookup()}>Retry</button>
        </p>{/if}
      {#if displayedDefinitions.length}
        <DictionaryPanel
          definitions={displayedDefinitions}
          selected={model.selected}
          onSelect={(definition) => (model.selected = definition)}
        />
        {#if !model.definitions.length && model.saved}<p class="mt-3 text-xs text-muted-foreground">
            Saved meaning · available offline
          </p>{/if}
        <p class="mt-3 border-b border-border pb-3 text-xs text-muted-foreground">
          Dictionary form · <span lang="ko">
            {model.matchedTerm || model.saved?.normalizedForm || terms[1] || analysis.word}
          </span>
        </p>
      {:else if !model.loading}
        <p class="mb-5 text-sm text-muted-foreground">
          {model.error
            ? "You can still save this word with your own meaning."
            : "No dictionary meanings found."}
        </p>
      {/if}
      {#if !displayedDefinitions.length}
        <p class="mb-3 text-xs text-muted-foreground">Word breakdown</p>
        <ol class="grid gap-3">
          {#each parts as part, index (index)}<li>
              <button
                class="font-[family-name:var(--font-korean)] underline decoration-dotted"
                onclick={() => model.lookup([part.term])}
                data-testid={`lookup-${part.term}`}
              >
                {part.term}
              </button><span class="ml-2 text-xs text-muted-foreground">
                {partOfSpeechLabel(part.tag)}
              </span>{#if part.explanation}<p class="mt-1 text-xs text-muted-foreground">
                  {part.explanation}
                </p>{/if}
            </li>{/each}
        </ol>
      {/if}
      {#if model.saveError && !editing}<p role="alert" class="mt-3 text-sm text-destructive">
          {model.saveError}
        </p>{/if}
    </div>
    {#each frames.filter((id) => $embedSettings.enabled.includes(id)) as id (id)}
      <div
        id={`analysis-pane-${id}`}
        role="tabpanel"
        aria-labelledby={`analysis-tab-${id}`}
        class="frame-pane"
        style:display={activeTab === id ? "flex" : "none"}
        data-testid={`embed-frame-${id}`}
      >
        <div class="browser-link">
          <button
            class="text-xs text-muted-foreground underline"
            onclick={() => void openExternal(url(id))}
          >
            Open in browser
          </button>
        </div>
        <p class="px-5 pb-2 text-xs text-muted-foreground">
          {frameErrors[id] || "If the dictionary doesn't load here, open it in your browser."}
        </p>
        <iframe
          title={label(id)}
          src={url(id)}
          sandbox="allow-scripts allow-same-origin allow-popups"
          onerror={() =>
            (frameErrors = {
              ...frameErrors,
              [id]: "This dictionary could not load here. Open it in your browser.",
            })}
        ></iframe>
      </div>
    {/each}
  </div>
  {#if editing}
    <SaveWordPanel
      initial={draft}
      saved={!!model.saved}
      saving={model.saving}
      error={model.saveError}
      onSave={(draft) => model.save(draft)}
      onRemove={() => model.remove()}
      onClose={closeEditor}
    />
  {:else}
    <details class="sources">
      <summary>Sources</summary>
      <div class="grid gap-2 pt-2">
        {#each sources as source (source)}<button
            class="text-left underline"
            onclick={() => void openExternal(source)}
          >
            {source.includes("wiktionary.org") ? "Wiktionary · CC BY-SA" : "KRDict"} · {source}
          </button>{:else}<p>No dictionary sources loaded.</p>{/each}
      </div>
    </details>
  {/if}
</section>

<style>
  .analysis {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: calc(var(--app-height) - 80px);
    min-height: 440px;
    overflow: hidden;
    background: var(--card);
    border: 1px solid var(--border);
  }
  .analysis.docked {
    height: 100%;
    min-height: 0;
    border-top: 0;
    border-bottom: 0;
    border-right: 0;
  }
  .tabs-row {
    display: flex;
    align-items: center;
    gap: 3px;
    padding: 4px 8px 0;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }
  .tabs {
    display: flex;
    flex: 1;
    min-width: 0;
    overflow-x: auto;
  }
  .tabs button {
    flex: 1 0 auto;
    min-width: 90px;
    padding: 10px 15px;
    font-size: 13px;
    color: var(--muted-foreground);
    border: 1px solid transparent;
    border-bottom: 0;
    border-radius: 12px 12px 0 0;
  }
  .tabs button.active {
    color: var(--foreground);
    background: var(--card);
    border-color: var(--border);
  }
  .word-header {
    display: flex;
    align-items: center;
    gap: 7px;
    padding: 15px 20px 22px;
    flex-shrink: 0;
  }
  h2 {
    font-family: var(--font-korean);
    font-size: 19px;
    line-height: 1.4;
    overflow-wrap: anywhere;
  }
  .body {
    min-height: 0;
    flex: 1;
    position: relative;
    display: flex;
    flex-direction: column;
    overflow: auto;
  }
  .analysis-body {
    padding: 12px 20px 20px;
  }
  .frame-pane {
    flex: 1;
    min-height: 300px;
    flex-direction: column;
  }
  .browser-link {
    display: flex;
    justify-content: end;
    padding: 0 24px 12px;
  }
  iframe {
    border: 0;
    width: 100%;
    flex: 1;
    min-height: 300px;
  }
  .sources {
    padding: 10px 20px;
    border-top: 1px solid var(--border);
    font-size: 12px;
    color: var(--muted-foreground);
    overflow-wrap: anywhere;
    max-height: 25%;
    overflow: auto;
  }
  .sources summary {
    cursor: pointer;
  }
</style>
