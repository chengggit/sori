<script lang="ts">
  import { untrack } from "svelte";
  import { openUrl } from "@tauri-apps/plugin-opener";
  import { Button } from "$lib/components/ui/button";
  import { dictionaryLicense, lookupDictionary, type DictionaryDefinition } from "./dictionary";

  let {
    term,
    savedDefinition,
    locked,
    onSelect,
  }: {
    term: string;
    savedDefinition?: DictionaryDefinition | null;
    locked: boolean;
    onSelect: (definition: DictionaryDefinition | null) => void;
  } = $props();
  let query = $state("");
  let searched = $state("");
  let definitions = $state<DictionaryDefinition[]>([]);
  let chosen = $state(-1);
  let loading = $state(false);
  let error = $state("");
  let request = 0;

  $effect(() => {
    const value = term;
    query = value;
    if (savedDefinition) {
      request += 1;
      definitions = [savedDefinition];
      searched = savedDefinition.term;
      query = savedDefinition.term;
      chosen = 0;
      loading = false;
      error = "";
    } else {
      untrack(() => void search(value));
    }
    return () => {
      request += 1;
    };
  });

  async function search(value: string) {
    const current = ++request;
    searched = value.trim();
    chosen = -1;
    definitions = [];
    onSelect(null);
    error = "";
    loading = false;
    if (!searched) return;
    loading = true;
    try {
      const result = await lookupDictionary(searched);
      if (current === request) definitions = result;
    } catch (cause) {
      if (current === request) error = String(cause);
    } finally {
      if (current === request) loading = false;
    }
  }

  async function open(url: string) {
    try {
      await openUrl(url);
    } catch (cause) {
      error = String(cause);
    }
  }
</script>

<section class="my-4 border-y py-4" aria-label="Dictionary">
  <h3 class="mb-2 text-sm font-medium">{savedDefinition ? "Saved meaning" : "Dictionary"}</h3>
  {#if !savedDefinition}
    <form
      class="mb-3 flex gap-2"
      onsubmit={(event) => {
        event.preventDefault();
        void search(query);
      }}
    >
      <input
        aria-label="Dictionary word"
        lang="ko"
        maxlength="100"
        bind:value={query}
        class="h-8 min-w-0 flex-1 rounded-md border bg-background px-2 text-sm"
      />
      <Button type="submit" size="sm" variant="outline" disabled={loading || !query.trim()}
        >Look up</Button
      >
    </form>
  {/if}
  {#if loading}
    <p role="status" class="text-sm text-muted-foreground">Looking up {searched}…</p>
  {:else if definitions.length}
    <fieldset class="space-y-3" disabled={locked}>
      <legend class="sr-only">Meaning to save</legend>
      {#each definitions as definition, index}
        <label class="flex items-start gap-2 text-sm">
          {#if !savedDefinition}
            <input
              type="radio"
              name="dictionary-meaning"
              class="mt-1"
              checked={chosen === index}
              onchange={() => {
                chosen = index;
                onSelect(definition);
              }}
            />
          {/if}
          <span
            ><span class="block text-xs text-muted-foreground"
              >{definition.term} · {definition.partOfSpeech}</span
            >{definition.text}</span
          >
        </label>
      {/each}
    </fieldset>
    {#if chosen >= 0 && !savedDefinition}
      <Button
        size="sm"
        variant="ghost"
        class="mt-2"
        disabled={locked}
        onclick={() => {
          chosen = -1;
          onSelect(null);
        }}>Clear meaning</Button
      >
    {/if}
  {:else if !error && searched}
    <p role="status" class="text-sm text-muted-foreground">
      No Korean entry for {searched}. Try a morpheme or another dictionary form.
    </p>
  {/if}
  {#if error}<p role="alert" class="text-sm text-destructive">{error}</p>{/if}
  <div class="mt-3 flex flex-wrap gap-x-3 gap-y-1 text-xs text-muted-foreground">
    <button
      type="button"
      class="underline"
      onclick={() =>
        open(
          definitions[0]?.sourceUrl ??
            `https://en.wiktionary.org/wiki/${encodeURIComponent(searched)}#Korean`,
        )}>Wiktionary</button
    >
    <button type="button" class="underline" onclick={() => open(dictionaryLicense)}>CC BY-SA 4.0</button
    >
    <button
      type="button"
      class="underline"
      onclick={() => open(`https://en.dict.naver.com/#/search?query=${encodeURIComponent(searched)}`)}
      >Open in Naver</button
    >
  </div>
  {#if definitions.length}<p class="mt-1 text-xs text-muted-foreground">
      From Wiktionary contributors. Formatting removed.
    </p>{/if}
</section>
