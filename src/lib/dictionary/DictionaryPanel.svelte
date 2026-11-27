<script lang="ts">
  import { ExternalLink, Search } from "@lucide/svelte";
  import { onDestroy, onMount } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import { embeddedLookupUrl, type EmbeddedProvider } from "$lib/dictionary/embedded";
  import { embedSettings, loadEmbedSettings } from "$lib/dictionary/embed-settings";
  import {
    dictionarySettings,
    lookupWord,
    openExternal,
    saveDictionaryKey,
    selectDictionary,
    type DictionaryDefinition,
    type DictionaryProvider,
  } from "$lib/dictionary/lookup";

  let { term }: { term: string } = $props();

  let provider = $state<DictionaryProvider>("wiktionary");
  let definitions = $state<DictionaryDefinition[]>([]);
  let error = $state("");
  let loading = $state(false);
  let apiKey = $state("");
  let hasKey = $state(false);

  let activeTab = $state<string | null>(null);
  let visibleTabs = $state<Record<string, boolean>>({});
  let dragged = $state<string | null>(null);
  const timers = new Map<string, ReturnType<typeof setTimeout>>();

  async function lookup() {
    if (!term.trim()) {
      definitions = [];
      return;
    }
    loading = true;
    error = "";
    try {
      const reply = await lookupWord(term.trim(), provider);
      if (!reply.ok) error = reply.error;
      else definitions = reply.data ?? [];
    } finally {
      loading = false;
    }
  }

  async function refreshSettings() {
    const reply = await dictionarySettings();
    if (!reply.ok || !reply.data) return;
    provider = reply.data.provider;
    hasKey = reply.data.hasKey;
  }

  async function saveKey() {
    const reply = await saveDictionaryKey(apiKey);
    if (!reply.ok) error = reply.error;
    else {
      apiKey = "";
      await refreshSettings();
    }
  }

  async function chooseProvider(next: DictionaryProvider) {
    const reply = await selectDictionary(next);
    if (!reply.ok) error = reply.error;
    else provider = next;
  }

  function urlFor(id: string) {
    const custom = $embedSettings.custom.find((entry) => entry.id === id);
    const kind: EmbeddedProvider = custom ? "custom" : (id as EmbeddedProvider);
    return embeddedLookupUrl(kind, term, custom?.url ?? "");
  }

  function showTab(id: string) {
    for (const timer of timers.values()) clearTimeout(timer);
    timers.clear();
    activeTab = id;
    visibleTabs = { ...visibleTabs, [id]: true };
    for (const key of Object.keys(visibleTabs)) {
      if (key === id) continue;
      timers.set(
        key,
        setTimeout(() => {
          const next = { ...visibleTabs };
          delete next[key];
          visibleTabs = next;
        }, 30_000),
      );
    }
  }

  function reorder(target: string) {
    if (!dragged || dragged === target) return;
    const enabled = [...$embedSettings.enabled];
    const from = enabled.indexOf(dragged);
    const to = enabled.indexOf(target);
    if (from < 0 || to < 0) return;
    enabled.splice(from, 1);
    enabled.splice(to, 0, dragged);
    embedSettings.update((settings) => ({ ...settings, enabled }));
    dragged = null;
  }

  onMount(() => {
    loadEmbedSettings();
    void refreshSettings();
  });

  onDestroy(() => {
    for (const timer of timers.values()) clearTimeout(timer);
  });

  $effect(() => {
    term;
    provider;
    void lookup();
  });
</script>

<section class="flex flex-col gap-3" data-testid="dictionary-panel">
  <div class="flex flex-wrap items-center gap-2">
    <Search size={16} class="text-muted-foreground" />
    <strong class="font-[family-name:var(--font-korean)]">{term}</strong>
    <select
      class="rounded-md border border-input bg-transparent px-2 py-1 text-sm"
      aria-label="Dictionary provider"
      value={provider}
      onchange={(event) => void chooseProvider(event.currentTarget.value as DictionaryProvider)}
    >
      <option value="wiktionary">Wiktionary</option>
      <option value="krdict">KRDict</option>
    </select>
  </div>

  {#if provider === "krdict" && !hasKey}
    <div class="flex flex-wrap items-center gap-2">
      <Input
        class="max-w-xs"
        type="password"
        placeholder="32-character KRDict key"
        aria-label="KRDict API key"
        bind:value={apiKey}
      />
      <Button variant="outline" onclick={saveKey} disabled={apiKey.length !== 32}>Save key</Button>
    </div>
  {/if}

  {#if error}
    <p class="text-sm text-destructive" role="alert" data-testid="dictionary-error">{error}</p>
  {/if}
  {#if loading}
    <p class="text-sm text-muted-foreground">Looking up…</p>
  {/if}

  <ul class="flex flex-col gap-2" data-testid="dictionary-definitions">
    {#each definitions as definition (definition.sourceUrl + definition.text)}
      <li class="rounded-md border border-border bg-card p-2 text-sm">
        <div class="flex items-center gap-2">
          <span class="font-semibold">{definition.term}</span>
          <span class="text-xs text-muted-foreground">{definition.partOfSpeech}</span>
          {#if definition.hanja}
            <span class="font-[family-name:var(--font-korean)] text-xs">{definition.hanja}</span>
          {/if}
        </div>
        <p class="whitespace-pre-wrap">{definition.text}</p>
        {#if definition.note}<p class="text-muted-foreground">{definition.note}</p>{/if}
        <button
          type="button"
          class="mt-1 inline-flex items-center gap-1 text-xs text-accent"
          onclick={() => void openExternal(definition.sourceUrl)}
        >
          <ExternalLink size={12} /> Open full entry
        </button>
      </li>
    {/each}
  </ul>

  <div>
    <p class="mb-1 text-xs text-muted-foreground">Embedded dictionaries (drag to reorder)</p>
    <div class="flex flex-wrap gap-1" role="tablist" aria-label="Embedded dictionaries">
      {#each $embedSettings.enabled as id (id)}
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === id}
          draggable="true"
          class="rounded-md border border-border px-2 py-1 text-xs hover:bg-neutral-hover"
          class:bg-accent-soft={activeTab === id}
          onclick={() => showTab(id)}
          ondragstart={() => (dragged = id)}
          ondragover={(event) => event.preventDefault()}
          ondrop={() => reorder(id)}
          data-testid={`embed-tab-${id}`}
        >
          {id === "naver-ko" ? "Naver" : id === "papago" ? "Papago" : "Custom"}
        </button>
      {/each}
    </div>

    {#each Object.keys(visibleTabs).filter((id) => visibleTabs[id]) as id (id)}
      <div class="mt-2 rounded-md border border-border" data-testid={`embed-frame-${id}`}>
        <div class="flex items-center justify-between border-b border-border px-2 py-1 text-xs">
          <span>{id}</span>
          <button
            type="button"
            class="inline-flex items-center gap-1"
            onclick={() => void openExternal(urlFor(id))}
          >
            <ExternalLink size={12} /> Open in browser
          </button>
        </div>
        <iframe
          title={id}
          src={urlFor(id)}
          class="h-72 w-full border-0"
          loading="lazy"
          sandbox="allow-scripts allow-same-origin allow-popups"
        ></iframe>
      </div>
    {/each}
  </div>
</section>
