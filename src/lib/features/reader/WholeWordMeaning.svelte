<script lang="ts">
  import { untrack } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import type { KoreanToken } from "../nlp/tokenization";
  import { lookupDictionary, type DictionaryDefinition } from "../dictionary/dictionary";
  import { wholeWordTerms } from "./breakdown";

  let {
    word,
    tokens,
    selected,
    savedDefinition,
    locked,
    onSelect,
    onSources,
    compact = false,
  }: {
    word: string;
    tokens: KoreanToken[];
    selected: DictionaryDefinition | null;
    savedDefinition?: DictionaryDefinition | null;
    locked: boolean;
    onSelect: (definition: DictionaryDefinition) => void;
    onSources: (definitions: DictionaryDefinition[]) => void;
    compact?: boolean;
  } = $props();
  const terms = $derived(wholeWordTerms(word, tokens));
  let definitions = $state<DictionaryDefinition[]>([]);
  let matchedTerm = $state("");
  let loading = $state(false);
  let error = $state("");
  let expanded = $state(false);
  let request = 0;

  $effect(() => {
    const candidates = terms;
    untrack(() => void search(candidates));
    return () => {
      request += 1;
    };
  });

  async function search(candidates: string[]) {
    const current = ++request;
    definitions = [];
    expanded = false;
    matchedTerm = "";
    error = "";
    loading = true;
    try {
      for (const term of candidates) {
        const result = await lookupDictionary(term);
        if (current !== request) return;
        if (result.length) {
          definitions = result;
          onSources(result);
          matchedTerm = term;
          break;
        }
      }
    } catch (cause) {
      if (current === request) error = String(cause);
    } finally {
      if (current === request) loading = false;
    }
  }
</script>

{#if compact}
  <div aria-label="Dictionary lookup" class="space-y-2 text-sm leading-relaxed wrap-anywhere">
    {#if loading}
      <p role="status" class="text-muted-foreground">Looking up meaning…</p>
    {:else if definitions.length}
      {#each expanded ? definitions : definitions.slice(0, 1) as definition}
        <p>{definition.text}</p>
      {/each}
      {#if definitions.length > 1}
        <button
          type="button"
          class="text-xs text-muted-foreground underline hover:text-foreground"
          aria-expanded={expanded}
          onclick={() => (expanded = !expanded)}
        >{expanded ? "Show fewer definitions" : "Show more definitions"}</button>
      {/if}
    {:else if savedDefinition}
      <p>{savedDefinition.text}</p>
    {:else if error}
      <button type="button" class="text-xs underline" onclick={() => search(terms)}>Retry lookup</button>
    {:else}
      <p class="text-muted-foreground">No definition found.</p>
    {/if}
  </div>
{:else}
{#if savedDefinition}
  <section aria-label="Saved meaning" class="mb-4">
    <h3 class="mb-1 text-xs font-medium text-muted-foreground">Saved meaning</h3>
    <p class="text-base leading-relaxed wrap-anywhere whitespace-pre-wrap">
      {#if savedDefinition.hanja}<span lang="ko" class="mr-2 text-base font-serif tracking-wide text-muted-foreground">{savedDefinition.hanja}</span>{/if}
      {savedDefinition.text}
    </p>
  </section>
{/if}

<section aria-label="Dictionary lookup" class="mb-5 border-b pb-4">
  <h3 class="mb-1 text-xs font-medium text-muted-foreground">Dictionary lookup</h3>
  {#if loading}
    <p role="status" class="text-sm text-muted-foreground">Looking up word meaning…</p>
  {:else if definitions.length}
    <ul class="space-y-2">
      {#each (expanded ? definitions : definitions.slice(0, 3)) as definition}
        <li>
          <button
            type="button"
            disabled={locked}
            aria-pressed={selected?.term === definition.term && selected?.text === definition.text}
            aria-label={`Choose word meaning to save: ${definition.text}`}
            onclick={() => onSelect(definition)}
            class="w-full rounded-md py-1 text-left text-base leading-relaxed hover:bg-accent focus-visible:outline-2 focus-visible:outline-ring aria-pressed:bg-accent disabled:cursor-default"
          >
            {#if definition.hanja}<span lang="ko" class="mr-2 text-base font-serif tracking-wide text-muted-foreground">{definition.hanja}</span>{/if}
            {definition.text}
          </button>
        </li>
      {/each}
    </ul>
    {#if definitions.length > 3}
      <button
        type="button"
        class="mt-2 px-2 text-xs font-medium text-muted-foreground underline hover:text-foreground"
        onclick={() => (expanded = !expanded)}
      >{expanded ? "Show fewer meanings" : `See ${definitions.length - 3} more meanings`}</button
      >
    {/if}
    {#if matchedTerm !== word}
      <p class="mt-2 text-xs text-muted-foreground">
        Dictionary form · <span lang="ko">{matchedTerm}</span>
      </p>
    {/if}
  {:else if !error}
    <p class="text-sm text-muted-foreground">No definition found.</p>
  {/if}
  {#if error}
    <p role="alert" class="text-sm text-destructive">{error}</p>
    <Button size="sm" variant="outline" class="mt-2" onclick={() => search(terms)}
      >Retry word lookup</Button
    >
  {/if}
</section>
{/if}
