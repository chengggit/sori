<script lang="ts">
  import { onMount } from "svelte";
  import TokenPassage from "$lib/reader/TokenPassage.svelte";
  import { readingPassages, type TokenBlock } from "$lib/reader/tokens";
  import { trackReadingProgress } from "$lib/reader/progress";
  import { saveTextPosition, type TextTranscript } from "./commands";
  import type { WordSource } from "$lib/analysis/state.svelte";
  import { ui } from "$lib/ui-state.svelte";
  let {
    text,
    source,
    onAnalyze,
    onError,
    isCurrent,
  }: {
    text: TextTranscript;
    source: WordSource;
    onAnalyze: (block: TokenBlock, context: string) => void;
    onError: (message: string) => void;
    isCurrent: (text: TextTranscript) => boolean;
  } = $props();
  let root = $state<HTMLDivElement>();
  onMount(() => {
    return trackReadingProgress(
      root!,
      text.position ?? 0,
      async (position) => {
        if (!isCurrent(text)) return;
        const reply = await saveTextPosition(source, position);
        if (!reply.ok) throw new Error(reply.error);
      },
      onError,
    );
  });
</script>

<div
  bind:this={root}
  class="text-transcript"
  data-testid="text-transcript"
  lang="ko"
  style:line-height={`${ui.transcriptLineHeight}px`}
>
  {#each readingPassages(text.content ?? "") as passage (passage.start)}<TokenPassage
      text={passage.text}
      start={passage.start}
      {root}
      selectedStart={undefined}
      onToken={(block) => onAnalyze(block, passage.text)}
    />{/each}
</div>

<style>
  .text-transcript {
    flex: 1;
    min-height: 0;
    overflow: auto;
    padding: 12px 24px 24px;
    white-space: pre-wrap;
    overflow-wrap: anywhere;
    font-family: var(--font-korean);
  }
</style>
