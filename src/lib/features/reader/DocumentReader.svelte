<script lang="ts">
  import { onDestroy, tick } from "svelte";
  import { X } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { analyzeDocumentWord, type WordAnalysis } from "./analysis";
  import { saveReadingProgress, trackReadingProgress } from "./progress";
  import TokenPassage from "./TokenPassage.svelte";
  import { readingPassages, partOfSpeechLabel, type TokenBlock } from "./tokens";
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
  let selection = $state<TokenBlock>();
  const passages = $derived(readingPassages(document.content));
  let analysis = $state<WordAnalysis>();
  let saved = $state<VocabularyEntry>();
  let normalized = $state("");
  let loading = $state(false);
  let saving = $state(false);
  let error = $state("");
  let request = 0;
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

<div class="flex min-h-0 min-w-0 flex-1">
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
      aria-label="Word analysis"
      class="w-72 max-w-[45%] shrink-0 overflow-y-auto border-l bg-popover px-4 pt-5 pb-6 sm:px-5"
    >
      <div class="mb-2 flex items-center justify-between gap-3">
        <h2 lang="ko" class="text-xl font-semibold wrap-break-word">{selection.text}</h2>
        <Button variant="ghost" size="icon-sm" aria-label="Close word analysis" onclick={dismiss}
          ><X /></Button
        >
      </div>
      {#if loading}
        <p role="status" class="text-sm text-muted-foreground">Analyzing…</p>
      {:else if analysis}
        <p lang="ko" class="mb-3 text-sm text-muted-foreground whitespace-pre-wrap">
          {analysis.context}
        </p>
        <h3 class="mb-2 text-sm font-medium">Word breakdown</h3>
        <ul class="mb-3 flex flex-wrap gap-2" aria-label="Morphemes">
          {#each analysis.morphemes as token, index (index)}
            <li>
              <button
                type="button"
                disabled={saving || !!saved}
                aria-pressed={normalized === token.form}
                onclick={() => (normalized = token.form)}
                class="rounded-md border px-2 py-1 text-sm hover:bg-accent focus-visible:outline-2 focus-visible:outline-ring aria-pressed:bg-accent"
              >
                <span lang="ko">{token.form}</span>
                <span class="block text-xs text-muted-foreground"
                  >{partOfSpeechLabel(token.tag)} · {token.tag}</span
                >
              </button>
            </li>
          {/each}
        </ul>
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
    </aside>
  {/if}
</div>
