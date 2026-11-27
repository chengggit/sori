<script lang="ts">
  import { ArrowLeft } from "@lucide/svelte";
  import { onDestroy, onMount, tick } from "svelte";
  import AnalysisPanel from "$lib/reader/AnalysisPanel.svelte";
  import PdfReader from "$lib/reader/PdfReader.svelte";
  import { Button } from "$lib/components/ui/button";
  import type { Analysis } from "$lib/reader/analysis";
  import { readingPassages, tokenBlocks } from "$lib/reader/tokens";
  import { trackReadingProgress } from "$lib/reader/progress";
  import { tokenizeText, type KoreanToken } from "$lib/nlp/tokenization";
  import { ui } from "$lib/ui-state.svelte";
  import {
    readDocument,
    saveDocumentProgress,
    saveWord,
    type DocumentView,
    type VocabularyDraft,
  } from "$lib/library/commands";

  let { documentId, onBack }: { documentId: number; onBack: () => void } = $props();

  type Passage = { text: string; start: number; tokens: KoreanToken[] };

  let document = $state<DocumentView | null>(null);
  let passages = $state<Passage[]>([]);
  let selected = $state<Analysis | null>(null);
  let error = $state("");
  let scroller = $state<HTMLElement>();
  let stopTracking: (() => void) | undefined;

  let active = true;
  onDestroy(() => {
    active = false;
    stopTracking?.();
  });
  onMount(() => {
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

    for (const [index, part] of parts.entries()) {
      try {
        const tokens = await tokenizeText(part.text);
        if (!active) return;
        passages[index].tokens = tokens;
      } catch (cause) {
        error = cause instanceof Error ? cause.message : String(cause);
        return;
      }
    }

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
    selected = {
      word: block.text,
      context: (passage?.text ?? block.text).trim(),
      tokens: block.morphemes,
    };
  }

  async function analyzePdfWord(word: string) {
    try {
      selected = { word, context: word, tokens: await tokenizeText(word) };
    } catch (cause) {
      error = cause instanceof Error ? cause.message : String(cause);
    }
  }

  function savePdfProgress(position: number) {
    void saveDocumentProgress(documentId, position).then((saved) => {
      if (!saved.ok) error = saved.error;
    });
  }

  async function save(draft: VocabularyDraft) {
    const saved = await saveWord("document", documentId, draft);
    if (!saved.ok) error = saved.error;
  }
</script>

<div class="flex flex-col gap-3">
  <Button variant="ghost" onclick={onBack} class="self-start">
    <ArrowLeft /> Back to library
  </Button>

  {#if error}
    <p class="text-sm text-destructive" role="alert" data-testid="reader-error">{error}</p>
  {/if}

  <div class="flex flex-wrap gap-4">
    {#if document?.pdfPath}
      <div class="min-w-0 flex-1" data-testid="pdf-reader">
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
        class="h-[60vh] min-w-0 flex-1 overflow-auto rounded-lg border border-border bg-card p-6 whitespace-pre-wrap"
        style:font-family={ui.readingFont === "noto" ? "var(--font-korean)" : "var(--font-ui)"}
        style:font-size={`${ui.readerTextSize}px`}
        style:line-height={`${ui.readerLineHeight}px`}
      >
        {#each passages as passage, passageIndex (passageIndex)}{#each tokenBlocks(passage.text, passage.tokens) as block, blockIndex (blockIndex)}{#if block.morphemes.length}<button
                type="button"
                data-testid={`token-${block.start}`}
                class="rounded underline decoration-dotted underline-offset-4 hover:bg-accent-soft"
                onclick={() => analyze(block)}
              >
                {block.text}
              </button>{:else}<span>{block.text}</span>{/if}{/each}{/each}
      </div>
    {/if}

    {#if selected}
      <aside class="w-full min-w-72 max-w-md" data-testid="reader-analysis">
        <AnalysisPanel analysis={selected} onSave={save} />
      </aside>
    {/if}
  </div>
</div>
