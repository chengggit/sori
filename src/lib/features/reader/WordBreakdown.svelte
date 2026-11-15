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
    savedWord,
    locked,
    onSelect,
    onSources,
  }: {
    tokens: KoreanToken[];
    selected: DictionaryDefinition | null;
    savedDefinition?: DictionaryDefinition | null;
    savedWord?: string;
    locked: boolean;
    onSelect: (definition: DictionaryDefinition) => void;
    onSources: (definitions: DictionaryDefinition[]) => void;
  } = $props();
  const parts = $derived(wordBreakdown(tokens));
  type Result = { definitions: DictionaryDefinition[]; error: string };
  let results = $state<Record<string, Result>>({});
  let expanded = $state<Record<string, boolean>>({});

  $effect(() => {
    const snapshot = savedDefinition;
    const snapshotPart = parts.find((part) => !part.explanation && part.term === savedWord)
      ?? parts.find((part) => !part.explanation && part.term === snapshot?.term);
    const snapshotTerm = snapshot && snapshotPart?.term;
    const terms = [
      ...new Set(
        parts
          .filter((part) => !part.explanation && part.term !== snapshotTerm)
          .map((part) => part.term),
      ),
    ];
    let disposed = false;
    results = snapshot && snapshotTerm ? { [snapshotTerm]: { definitions: [snapshot], error: "" } } : {};
    expanded = {};
    untrack(() => {
      if (snapshot && snapshotTerm) onSources([snapshot]);
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
            {#each (expanded[part.term] ? result.definitions : result.definitions.slice(0, 3)) as definition}
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
                  {#if definition.hanja}<span lang="ko" class="mr-2 text-base font-serif tracking-wide text-muted-foreground">{definition.hanja}</span>{/if}
                  {definition.text}
                </button>
              </li>
            {/each}
          </ul>
          {#if result.definitions.length > 3}
            <button
              type="button"
              class="mt-2 px-2 text-xs font-medium text-muted-foreground underline hover:text-foreground"
              onclick={() => (expanded = { ...expanded, [part.term]: !expanded[part.term] })}
            >{expanded[part.term] ? "Show fewer meanings" : `See ${result.definitions.length - 3} more meanings`}</button
            >
          {/if}
        {:else}
          <p class="text-sm text-muted-foreground">No definition found.</p>
        {/if}
      </li>
    {/each}
  </ul>
</section>
