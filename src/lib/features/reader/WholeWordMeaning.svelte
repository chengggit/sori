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
  }: {
    word: string;
    tokens: KoreanToken[];
    selected: DictionaryDefinition | null;
    savedDefinition?: DictionaryDefinition | null;
    locked: boolean;
    onSelect: (definition: DictionaryDefinition) => void;
    onSources: (definitions: DictionaryDefinition[]) => void;
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
    const snapshot = savedDefinition;
    untrack(() => {
      if (snapshot && candidates.includes(snapshot.term)) {
        request += 1;
        definitions = [snapshot];
        expanded = false;
        onSources([snapshot]);
        matchedTerm = snapshot.term;
        loading = false;
        error = "";
      } else {
        void search(candidates);
      }
    });
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

<section aria-label="Whole-word meaning" class="mb-5 border-b pb-4">
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
    <p class="text-sm text-muted-foreground">No whole-word entry found.</p>
  {/if}
  {#if error}
    <p role="alert" class="text-sm text-destructive">{error}</p>
    <Button size="sm" variant="outline" class="mt-2" onclick={() => search(terms)}
      >Retry word lookup</Button
    >
  {/if}
</section>
