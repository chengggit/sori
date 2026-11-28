<script lang="ts">
  import type { DictionaryDefinition } from "./lookup";
  let {
    definitions,
    selected,
    onSelect,
  }: {
    definitions: DictionaryDefinition[];
    selected: DictionaryDefinition | null;
    onSelect: (definition: DictionaryDefinition) => void;
  } = $props();
  let expanded = $state(false);
  $effect(() => {
    definitions;
    expanded = false;
  });
</script>

<div data-testid="dictionary-panel">
  <p class="mb-3 text-xs text-muted-foreground">Dictionary lookup</p>
  <ul class="grid gap-3" data-testid="dictionary-definitions">
    {#each expanded ? definitions : definitions.slice(0, 3) as definition, index (index)}
      <li>
        <button
          type="button"
          class="meaning"
          aria-label={`Select meaning ${index + 1}`}
          aria-pressed={selected?.text === definition.text &&
            selected?.sourceUrl === definition.sourceUrl}
          onclick={() => onSelect(definition)}
        >
          <span class="hanja">{definition.hanja || definition.term}</span><span>{definition.text}</span>
        </button>
      </li>
    {/each}
  </ul>
  {#if definitions.length > 3}<button
      class="mt-3 text-xs text-muted-foreground underline"
      onclick={() => (expanded = !expanded)}
    >
      {expanded
        ? "Show fewer meanings"
        : `See ${definitions.length - 3} more ${definitions.length === 4 ? "meaning" : "meanings"}`}
    </button>{/if}
</div>

<style>
  .meaning {
    display: grid;
    grid-template-columns: auto minmax(0, 1fr);
    align-items: start;
    gap: 12px;
    width: 100%;
    border-radius: 6px;
    padding: 3px 5px;
    text-align: left;
    font-size: 16px;
    line-height: 1.3;
  }
  .meaning:hover,
  .meaning:focus-visible {
    background: var(--neutral-hover);
  }
  .hanja {
    padding-top: 2px;
    font-family: var(--font-korean);
    font-size: 13px;
    color: var(--muted-foreground);
  }
</style>
