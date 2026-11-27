<script lang="ts">
  import { ArrowLeft } from '@lucide/svelte';
  import { onDestroy, onMount, tick } from 'svelte';
  import AnalysisPanel from './AnalysisPanel.svelte';
  import { Button } from '$lib/components/ui/button';
  import type { Analysis } from '$lib/reader/analysis';
  import { readingPassages, tokenBlocks } from '$lib/reader/tokens';
  import { trackReadingProgress } from '$lib/reader/progress';
  import { tokenizeText, type KoreanToken } from '$lib/nlp/tokenization';
  import {
    readDocument,
    saveDocumentProgress,
    saveWord,
    type DocumentView,
    type VocabularyDraft,
  } from '$lib/library/commands';

  let { documentId, onBack }: { documentId: number; onBack: () => void } = $props();

  type Passage = { text: string; start: number; tokens: KoreanToken[] };

  let document = $state<DocumentView | null>(null);
  let passages = $state<Passage[]>([]);
  let selected = $state<Analysis | null>(null);
  let error = $state('');
  let scroller = $state<HTMLElement>();
  let stopTracking: (() => void) | undefined;

  onDestroy(() => stopTracking?.());
  onMount(() => {
    void open();
  });

  async function open() {
    const result = await readDocument(documentId);
    if (!result.ok || !result.data) {
      error = result.error || 'Document not found.';
      return;
    }
    document = result.data;
    if (result.data.pdfPath) {
      error = 'PDF reading arrives in a later step. This document is stored as a PDF.';
      return;
    }

    const parts = readingPassages(result.data.content);
    passages = parts.map((part) => ({ ...part, tokens: [] as KoreanToken[] }));
    await tick();

    for (const [index, part] of parts.entries()) {
      try {
        passages[index].tokens = await tokenizeText(part.text);
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

  async function save(draft: VocabularyDraft) {
    const saved = await saveWord('document', documentId, draft);
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
    <div
      bind:this={scroller}
      data-testid="reader-text"
      class="h-[60vh] min-w-0 flex-1 overflow-auto rounded-lg border border-border bg-card p-6 font-[family-name:var(--font-korean)] text-lg leading-10 whitespace-pre-wrap"
    >
      {#each passages as passage, passageIndex (passageIndex)}{#each tokenBlocks(passage.text, passage.tokens) as block, blockIndex (blockIndex)}{#if block.morphemes.length}<button
            type="button"
            data-testid={`token-${block.start}`}
            class="rounded underline decoration-dotted underline-offset-4 hover:bg-accent-soft"
            onclick={() => analyze(block)}
          >{block.text}</button>{:else}<span>{block.text}</span>{/if}{/each}{/each}
    </div>

    {#if selected}
      <aside class="w-full min-w-72 max-w-md" data-testid="reader-analysis">
        <AnalysisPanel analysis={selected} onSave={save} />
      </aside>
    {/if}
  </div>
</div>
