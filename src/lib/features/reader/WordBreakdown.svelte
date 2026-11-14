<script lang="ts">
  import { untrack } from "svelte";
  import type { KoreanToken } from "../nlp/tokenization";
  import { lookupDictionary, type DictionaryDefinition } from "../dictionary/dictionary";
  import { wordBreakdown } from "./breakdown";
  import { partOfSpeechLabel } from "./tokens";

  let {
    tokens,
    selected,
    savedDefinition,
    locked,
    onSelect,
    onSources,
  }: {
    tokens: KoreanToken[];
    selected: DictionaryDefinition | null;
    savedDefinition?: DictionaryDefinition | null;
    locked: boolean;
    onSelect: (definition: DictionaryDefinition) => void;
    onSources: (definitions: DictionaryDefinition[]) => void;
  } = $props();
  const parts = $derived(wordBreakdown(tokens));
  type Result = { definitions: DictionaryDefinition[]; error: string };
  let results = $state<Record<string, Result>>({});

  $effect(() => {
    const snapshot = savedDefinition;
    const terms = [
      ...new Set(
        parts
          .filter((part) => !part.explanation && part.term !== snapshot?.term)
          .map((part) => part.term),
      ),
    ];
    let disposed = false;
    results = snapshot ? { [snapshot.term]: { definitions: [snapshot], error: "" } } : {};
    untrack(() => {
      if (snapshot) onSources([snapshot]);
      for (const term of terms) {
        void lookupDictionary(term).then(
          (definitions) => {
            if (!disposed) {
              results = { ...results, [term]: { definitions, error: "" } };
              onSources(definitions);
            }
          },
          (cause) => {
            if (!disposed) results = { ...results, [term]: { definitions: [], error: String(cause) } };
          },
        );
      }
    });
    return () => {
      disposed = true;
    };
  });
</script>

<section aria-label="Word breakdown" class="mb-4">
  <h3 class="mb-3 text-sm font-medium">Word breakdown</h3>
  <ul class="divide-y">
    {#each parts as part, index (index)}
      {@const result = results[part.term]}
      <li class="py-3 first:pt-0">
        <div class="mb-1 flex flex-wrap items-baseline gap-x-2">
          <span lang="ko" class="font-medium">{part.term}</span>
          <span class="text-xs text-muted-foreground">{partOfSpeechLabel(part.tag)}</span>
        </div>
        {#if part.explanation}
          <p class="text-sm">{part.explanation}</p>
        {:else if !result}
          <p role="status" class="text-sm text-muted-foreground">Looking up meaning…</p>
        {:else if result.error}
          <p role="alert" class="text-sm text-muted-foreground">{result.error}</p>
        {:else if result.definitions.length}
          <ul class="space-y-2">
            {#each result.definitions as definition}
              <li>
                <button
                  type="button"
                  disabled={locked}
                  aria-pressed={selected?.term === definition.term &&
                    selected?.text === definition.text}
                  aria-label={`Choose meaning to save: ${definition.text}`}
                  onclick={() => onSelect(definition)}
                  class="w-full rounded-md px-2 py-1 text-left text-sm hover:bg-accent focus-visible:outline-2 focus-visible:outline-ring aria-pressed:bg-accent disabled:cursor-default"
                >
                  {definition.text}
                </button>
              </li>
            {/each}
          </ul>
        {:else}
          <p class="text-sm text-muted-foreground">No Korean definition found.</p>
        {/if}
      </li>
    {/each}
  </ul>
</section>
