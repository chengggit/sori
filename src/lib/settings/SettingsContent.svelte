<script lang="ts">
  import { onMount } from "svelte";
  import { Settings, BookOpen, Link } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import { loadEmbedSettings } from "$lib/dictionary/embed-settings";
  import type { DictionaryProvider } from "$lib/dictionary/lookup";
  import GeneralSettings from "./GeneralSettings.svelte";
  import EmbeddedSettings from "./EmbeddedSettings.svelte";
  import { SettingsModel } from "./state.svelte";
  let { onBusy = () => {} }: { onBusy?: (busy: boolean) => void } = $props();
  const model = new SettingsModel();
  let category = $state("general");
  const categories = [
    { id: "general", label: "General", icon: Settings },
    { id: "dictionaries", label: "Dictionaries", icon: BookOpen },
    { id: "connections", label: "Connections", icon: Link },
  ];
  $effect(() => onBusy(model.dictionary.busy || model.youtube.busy));
  onMount(() => {
    const unsubscribe = loadEmbedSettings();
    void model.loadDictionary();
    void model.loadYoutube();
    return () => {
      model.dispose();
      unsubscribe();
    };
  });
</script>

<div class="settings-layout" data-testid="settings-content">
  <nav aria-label="Settings categories">
    {#each categories as { id, label, icon: Icon } (id)}
      <button
        type="button"
        aria-current={category === id ? "true" : undefined}
        onclick={() => (category = id)}
      >
        <Icon size={14} />{label}
      </button>
    {/each}
  </nav>
  <div class="category" hidden={category !== "general"}><GeneralSettings /></div>
  <div class="category" hidden={category !== "dictionaries"}>
    <section class="settings-form" data-testid="dictionary-settings" aria-label="Analysis dictionary">
      <h2>Analysis dictionary</h2>
      <label>
        Analysis provider
        <select
          value={model.provider}
          disabled={model.dictionary.loading || model.dictionary.busy || !model.dictionary.ready}
          onchange={(event) => {
            const next = event.currentTarget.value as DictionaryProvider;
            event.currentTarget.value = model.provider;
            void model.chooseProvider(next);
          }}
        >
          <option value="wiktionary">Wiktionary</option><option value="krdict">KRDict</option>
        </select>
      </label>
      <p class="hint">
        Wiktionary works without a key. KRDict needs an API key; empty results fall back to Wiktionary.
        Saved meanings work offline.
      </p>
      {#if model.dictionary.loading}<p role="status" class="hint">
          Loading dictionary settings…
        </p>{:else if !model.dictionary.ready}<Button
          variant="outline"
          size="sm"
          onclick={() => void model.loadDictionary()}
        >
          Retry dictionary settings
        </Button>{/if}
      <form
        class="settings-form"
        onsubmit={(event) => {
          event.preventDefault();
          void model.saveKrdict();
        }}
      >
        <label>
          KRDict API key<Input
            type="password"
            aria-label="KRDict API key"
            autocomplete="off"
            spellcheck={false}
            placeholder={model.hasKrdictKey ? "Enter a replacement API key" : "32-character KRDict key"}
            bind:value={model.krdictKey}
            disabled={model.dictionary.loading || model.dictionary.busy || !model.dictionary.ready}
          />
        </label>
        {#if model.dictionary.ready}<p class="hint">
            {model.hasKrdictKey ? "KRDict key saved locally." : "No KRDict key saved."}
          </p>{/if}
        <div class="actions">
          <Button
            type="submit"
            variant="outline"
            size="sm"
            disabled={model.dictionary.loading ||
              model.dictionary.busy ||
              !model.krdictKey.trim() ||
              !model.dictionary.ready}
          >
            Save KRDict key
          </Button>
          {#if model.hasKrdictKey}<Button
              variant="ghost"
              size="sm"
              disabled={model.dictionary.loading || model.dictionary.busy}
              onclick={() => void model.removeKrdict()}
            >
              Remove KRDict key
            </Button>{/if}
        </div>
      </form>
      {#if model.dictionary.error}<p role="alert" class="settings-error">
          {model.dictionary.error}
        </p>{/if}
      {#if model.dictionary.message}<p role="status" class="hint">{model.dictionary.message}</p>{/if}
    </section>
    <div class="divider"></div>
    <EmbeddedSettings />
  </div>
  <div class="category" hidden={category !== "connections"}>
    <section class="settings-form" data-testid="youtube-settings" aria-label="YouTube connection">
      <h2>YouTube</h2>
      <p class="hint">Add your YouTube Data API key to enable Home and Explore discovery.</p>
      {#if model.youtube.loading}<p role="status" class="hint">
          Loading YouTube settings…
        </p>{:else if !model.youtube.ready}<Button
          variant="outline"
          size="sm"
          onclick={() => void model.loadYoutube()}
        >
          Retry YouTube settings
        </Button>{/if}
      <form
        class="settings-form"
        onsubmit={(event) => {
          event.preventDefault();
          void model.saveYoutube();
        }}
      >
        <label>
          YouTube API key<Input
            type="password"
            aria-label="YouTube API key"
            autocomplete="off"
            spellcheck={false}
            placeholder={model.hasYoutubeSavedKey
              ? "Enter a replacement API key"
              : "Paste your API key"}
            bind:value={model.youtubeKey}
            disabled={model.youtube.loading || model.youtube.busy || !model.youtube.ready}
          />
        </label>
        {#if model.youtube.ready}<p class="hint" data-testid="youtube-key-state">
            {model.hasYoutubeSavedKey
              ? "API key saved locally."
              : model.hasYoutubeKey
                ? "Using the environment API key."
                : "No YouTube API key configured."}
          </p>{/if}
        <div class="actions">
          <Button
            type="submit"
            variant="outline"
            size="sm"
            disabled={model.youtube.loading ||
              model.youtube.busy ||
              !model.youtubeKey.trim() ||
              !model.youtube.ready}
          >
            Save YouTube key
          </Button>
          {#if model.hasYoutubeSavedKey}<Button
              variant="ghost"
              size="sm"
              disabled={model.youtube.loading || model.youtube.busy}
              onclick={() => void model.removeYoutube()}
            >
              Remove YouTube key
            </Button>{/if}
        </div>
      </form>
      {#if model.youtube.error}<p role="alert" class="settings-error">{model.youtube.error}</p>{/if}
      {#if model.youtube.message}<p role="status" class="hint">{model.youtube.message}</p>{/if}
      <p class="hint">
        A saved key takes priority over the environment key. Removing it restores the environment
        fallback, when available.
      </p>
      <p class="hint">
        Opening YouTube links and fetching captions do not need a developer key. Manage subscribed
        channels in Explore.
      </p>
    </section>
  </div>
</div>

<style>
  .settings-layout {
    display: flex;
    min-height: 0;
    height: 100%;
  }
  nav {
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
    width: 190px;
    padding: 16px;
    gap: 4px;
    border-right: 1px solid var(--border);
  }
  nav button {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 10px;
    text-align: left;
    border-radius: 8px;
    font-size: 13px;
  }
  nav button:hover {
    background: var(--neutral-hover);
  }
  nav button[aria-current] {
    background: var(--accent-soft);
    color: var(--dashboard-accent);
    font-weight: 600;
  }
  .category {
    flex: 1;
    min-width: 0;
    overflow-y: auto;
    padding: 20px;
  }
  .category[hidden] {
    display: none;
  }
  .divider {
    height: 1px;
    background: var(--border);
    margin: 24px 0;
  }
  .actions {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
  }
  :global(.settings-form) {
    display: grid;
    gap: 14px;
  }
  :global(.settings-form label) {
    display: grid;
    gap: 8px;
    font-size: 14px;
  }
  :global(.settings-form h2),
  :global(.settings-form h3),
  :global(.settings-form legend) {
    font-size: 14px;
    font-weight: 600;
  }
  :global(.settings-form legend) {
    margin-bottom: 8px;
  }
  :global(.settings-form select) {
    width: 100%;
    border: 1px solid var(--border);
    border-radius: 8px;
    height: 38px;
    padding: 0 12px;
    background: var(--card);
    font-size: 13px;
  }
  :global(.settings-form input[type="range"]) {
    width: 100%;
    accent-color: var(--dashboard-accent);
  }
  :global(.settings-form .hint) {
    font-size: 12px;
    color: var(--muted-foreground);
    line-height: 1.6;
    font-weight: 400;
  }
  :global(.settings-form .setting-value) {
    float: right;
    justify-self: end;
    margin-top: -28px;
    font-size: 12px;
    color: var(--muted-foreground);
  }
  .settings-error {
    color: var(--destructive);
    font-size: 13px;
  }
  @media (max-width: 640px) {
    .settings-layout {
      flex-direction: column;
    }
    nav {
      flex-direction: row;
      width: 100%;
      border-right: 0;
      border-bottom: 1px solid var(--border);
      padding: 10px;
      gap: 2px;
    }
    nav button {
      flex: 1;
      justify-content: center;
      padding: 8px 6px;
      font-size: 12px;
      gap: 6px;
    }
    .category {
      padding: 16px;
    }
  }
</style>
