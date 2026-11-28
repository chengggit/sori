<script lang="ts">
  import { fly } from "svelte/transition";
  import AnalysisPanel from "$lib/reader/AnalysisPanel.svelte";
  import type { Analysis } from "$lib/reader/analysis";
  import type { WordSource } from "./state.svelte";

  let {
    analysis,
    source,
    onClose,
    testId,
  }: {
    analysis: Analysis;
    source: WordSource;
    onClose: () => void;
    testId: string;
  } = $props();
  const duration = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? 0 : 200;
</script>

<aside class="analysis-sidebar" data-testid={testId} transition:fly={{ x: 500, duration, opacity: 1 }}>
  <AnalysisPanel {analysis} {source} {onClose} docked />
</aside>

<style>
  .analysis-sidebar {
    position: fixed;
    z-index: 20;
    top: 3.5rem;
    right: 0;
    width: min(500px, 100%);
    height: calc(var(--app-height) - 3.5rem);
  }
</style>
