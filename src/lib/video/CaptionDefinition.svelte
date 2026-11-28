<script lang="ts">
  import { Bookmark, X } from "@lucide/svelte";
  import { onDestroy } from "svelte";
  import { AnalysisModel, type WordSource } from "$lib/analysis/state.svelte";
  import type { Analysis } from "$lib/reader/analysis";
  import { Button } from "$lib/components/ui/button";
  let {
    analysis,
    source,
    onClose,
    onExpand,
  }: { analysis: Analysis; source: WordSource; onClose: () => void; onExpand: () => void } = $props();
  const model = new AnalysisModel();
  $effect(() => model.start(analysis, source));
  onDestroy(() => model.destroy());
  async function bookmark() {
    if (model.saved) await model.remove();
    else
      await model.save({
        word: model.selected?.term || analysis.lookupTerms?.[1] || analysis.word,
        meaning: model.selected?.text || "",
        note: "",
        tags: [],
      });
  }
</script>

<section class="definition" aria-label="Subtitle definition" data-testid="caption-definition">
  <header class="flex items-center gap-2">
    <h3 class="mr-auto font-semibold" lang="ko">{analysis.word}</h3>
    <Button
      variant="ghost"
      size="icon-sm"
      aria-label={model.saved ? "Remove saved subtitle word" : "Save subtitle word"}
      aria-pressed={!!model.saved}
      disabled={model.saving}
      onclick={bookmark}
    >
      <Bookmark size={17} fill={model.saved ? "currentColor" : "none"} />
    </Button><Button
      variant="ghost"
      size="icon-sm"
      aria-label="Close subtitle definition"
      onclick={onClose}
    >
      <X size={15} />
    </Button>
  </header>
  <div class="definition-body">
    {#if model.loading}<p role="status">Looking up…</p>{/if}
    {#each model.definitions.slice(0, 3) as definition}<p>{definition.text}</p>{/each}
    {#if !model.loading && !model.definitions.length}<p>
        {model.error || "No dictionary meanings found. You can still save this word."}
      </p>{/if}
    {#if model.saveError}<p role="alert" class="text-destructive">{model.saveError}</p>{/if}
  </div>
  <Button variant="outline" size="sm" class="mt-3 w-full" onclick={onExpand}>Open full analysis</Button>
</section>

<style>
  .definition {
    width: min(352px, calc(100vw - 32px));
    padding: 12px 16px 16px;
    border-radius: 12px;
    background: var(--card);
    color: var(--foreground);
    border: 1px solid var(--border);
    box-shadow: 0 6px 30px #0003;
  }
  .definition-body {
    max-height: 25vh;
    overflow: auto;
    font-size: 13px;
  }
  .definition-body p {
    margin-top: 10px;
  }
</style>
