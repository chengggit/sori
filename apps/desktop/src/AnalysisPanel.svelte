<script lang="ts">
  import type { KoreanToken } from "./lib/nlp/tokenization";
  import type { Analysis } from "./lib/reader/analysis";
  import { wordBreakdown, wholeWordTerms } from "./lib/reader/breakdown";
  import { partOfSpeechLabel } from "./lib/reader/tokens";
  import type { VocabularyDraft } from "./lib/library/commands";

  let {
    analysis,
    onSave,
  }: {
    analysis: Analysis;
    onSave?: (draft: VocabularyDraft) => void;
  } = $props();

  const parts = $derived(wordBreakdown(analysis.tokens));
  const normalized = $derived(analysis.normalizedForm ?? parts.map((part) => part.form).join(""));
  const terms = $derived(analysis.lookupTerms ?? wholeWordTerms(analysis.word, analysis.tokens));

  function save() {
    onSave?.({
      word: analysis.word,
      normalizedForm: normalized,
      context: analysis.context || analysis.word,
      tags: [],
    });
  }
</script>

<section class="analysis" aria-label="Word analysis" data-testid="analysis-panel">
  <header>
    <strong>{analysis.word}</strong>
    <span class="normalized">{normalized}</span>
  </header>

  <ol>
    {#each parts as part, index (index)}
      <li>
        <span class="term">{part.term}</span>
        <span class="label">{partOfSpeechLabel(part.tag)}</span>
        {#if part.explanation}<span class="explanation">{part.explanation}</span>{/if}
      </li>
    {/each}
  </ol>

  <p class="terms">Look up: {terms.join(" · ")}</p>
  {#if onSave}
    <button type="button" onclick={save}>Save word</button>
  {/if}
</section>
