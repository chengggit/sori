<script lang="ts">
  import { onMount } from "svelte";
  import AnalysisPanel from "./AnalysisPanel.svelte";
  import type { Analysis } from "./lib/reader/analysis";
  import { tokenizeText, type KoreanToken } from "./lib/nlp/tokenization";

  let text = $state("😀 학교에 갔어요.");
  let tokens = $state<KoreanToken[]>([]);
  let error = $state("");

  const analysis = $derived<Analysis | null>(
    tokens.length ? { word: text.trim(), context: text.trim(), tokens } : null,
  );

  async function run() {
    try {
      tokens = await tokenizeText(text);
      error = "";
    } catch (cause) {
      tokens = [];
      error = cause instanceof Error ? cause.message : String(cause);
    }
  }

  onMount(() => {
    void run();
  });
</script>

<main>
  <h2>Analysis</h2>
  <label>
    Passage
    <textarea bind:value={text} rows="3" aria-label="Passage"></textarea>
  </label>
  <button type="button" onclick={run}>Analyze</button>
  {#if error}<p class="error" data-testid="analysis-error">{error}</p>{/if}
  {#if analysis}
    <AnalysisPanel {analysis} />
  {:else if !error}
    <p>No morphemes found.</p>
  {/if}
  <a href="#/">Back to app</a>
</main>
