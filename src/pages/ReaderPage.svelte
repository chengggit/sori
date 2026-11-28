<script lang="ts">
  import { onDestroy, onMount, tick } from "svelte";
  import AnalysisSidebar from "$lib/analysis/AnalysisSidebar.svelte";
  import PdfReader from "$lib/reader/PdfReader.svelte";
  import TokenPassage from "$lib/reader/TokenPassage.svelte";
  import type { Analysis } from "$lib/reader/analysis";
  import { readingPassages } from "$lib/reader/tokens";
  import { trackReadingProgress } from "$lib/reader/progress";
  import { tokenizeText, type KoreanToken } from "$lib/nlp/tokenization";
  import { ui } from "$lib/ui-state.svelte";
  import {
    readDocument,
    loadLibraryState,
    saveDocumentProgress,
    type DocumentView,
  } from "$lib/library/commands";

  let { documentId, onTitle }: { documentId: number; onTitle: (title: string) => void } = $props();

  type Passage = { text: string; start: number; tokens: KoreanToken[] };

  let document = $state<DocumentView | null>(null);
  let passages = $state<Passage[]>([]);
  let selected = $state<Analysis | null>(null);
  let error = $state("");
  let selectedStart = $state<number>();
  let selectionRequest = 0;
  let scroller = $state<HTMLElement>();
  let stopTracking: (() => void) | undefined;

  let active = true;
  onDestroy(() => {
    active = false;
    selectionRequest++;
    stopTracking?.();
  });
  onMount(() => {
    onTitle("");
    void loadLibraryState().then((reply) => {
      if (active)
        onTitle(
          reply.ok
            ? (reply.data?.documents?.find((item) => item.id === documentId)?.title ?? "Reader")
            : "Reader",
        );
    });
    void open();
  });

  async function open() {
    const result = await readDocument(documentId);
    if (!active) return;
    if (!result.ok || !result.data) {
      error = result.error || "Document not found.";
      return;
    }
    document = result.data;
    if (result.data.pdfPath) return;

    const parts = readingPassages(result.data.content);
    passages = parts.map((part) => ({ ...part, tokens: [] as KoreanToken[] }));
    await tick();
    if (!active) return;

    await window.document.fonts.ready;
    if (!active) return;

    stopTracking = trackReadingProgress(
      scroller!,
      result.data.position,
      async (position) => {
        const saved = await saveDocumentProgress(documentId, position);
        if (!saved.ok) throw new Error(saved.error);
      },
      (message) => (error = message),
    );
  }

  function analyze(block: { text: string; start: number; end: number; morphemes: KoreanToken[] }) {
    if (!block.morphemes.length) return;
    const passage = passages.find(
      (item) => block.start >= item.start && block.end <= item.start + item.text.length,
    );
    selectedStart = block.start;
    selected = {
      word: block.text,
      context: (passage?.text ?? block.text).trim(),
      tokens: block.morphemes,
    };
  }

  async function analyzePdfWord(word: string) {
    const request = ++selectionRequest;
    try {
      const tokens = await tokenizeText(word);
      if (!active || request !== selectionRequest) return;
      selected = { word, context: word, tokens };
    } catch (cause) {
      if (active && request === selectionRequest)
        error = cause instanceof Error ? cause.message : String(cause);
    }
  }

  function savePdfProgress(position: number) {
    void saveDocumentProgress(documentId, position).then((saved) => {
      if (!saved.ok) error = saved.error;
    });
  }
</script>

<div class="workspace" class:analysis-open={!!selected}>
  {#if error}<p class="reader-error text-sm text-destructive" role="alert" data-testid="reader-error">
      {error}
    </p>{/if}
  {#if document?.pdfPath}
    <div class="pdf-reader" data-testid="pdf-reader">
      <PdfReader
        {documentId}
        position={document.position}
        onProgress={savePdfProgress}
        onWord={analyzePdfWord}
      />
    </div>
  {:else}
    <div
      bind:this={scroller}
      data-testid="reader-text"
      class="text-scroller"
      style:font-family={ui.readingFont === "noto" ? "var(--font-korean)" : "var(--font-ui)"}
      style:font-size={`${ui.readerTextSize}px`}
      style:line-height={`${ui.readerLineHeight}px`}
    >
      <article class="text-column" lang="ko">
        {#each passages as passage (passage.start)}<TokenPassage
            text={passage.text}
            start={passage.start}
            root={scroller}
            {selectedStart}
            onToken={analyze}
          />{/each}
      </article>
    </div>
  {/if}
</div>

{#if selected}
  <AnalysisSidebar
    analysis={selected}
    source={{ kind: "document", id: documentId }}
    onClose={() => (selected = null)}
    testId="reader-analysis"
  />
{/if}

<style>
  .workspace {
    height: 100%;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }
  .pdf-reader,
  .text-scroller {
    flex: 1;
    min-height: 0;
  }
  .text-scroller {
    overflow: auto;
  }
  .text-column {
    max-width: 780px;
    margin: 0 auto;
    padding: 32px 16px 64px;
    white-space: pre-wrap;
    overflow-wrap: anywhere;
  }
  .reader-error {
    padding: 8px 20px;
  }

  @media (min-width: 1100px) {
    .workspace.analysis-open {
      padding-right: 500px;
    }
  }
</style>
