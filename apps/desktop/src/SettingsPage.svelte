<script lang="ts">
  import { onDestroy, onMount } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import { appearanceOptions, clampPageScale } from "$lib/appearance";
  import { ui } from "$lib/ui-state.svelte";
  import { embeddedProviders, validCustomEmbed } from "$lib/dictionary/embedded";
  import { embedSettings, loadEmbedSettings } from "$lib/dictionary/embed-settings";
  import {
    dictionarySettings,
    removeDictionaryKey,
    saveDictionaryKey,
    selectDictionary,
    type DictionaryProvider,
  } from "$lib/dictionary/lookup";
  import { removeYouTubeKey, saveYouTubeKey, youtubeSettings } from "$lib/youtube/commands";

  let provider = $state<DictionaryProvider>("wiktionary");
  let krdictKey = $state("");
  let hasKrdictKey = $state(false);
  let youtubeKey = $state("");
  let hasYoutubeKey = $state(false);
  let customUrl = $state("");
  let dragged = $state<string | null>(null);
  let error = $state("");
  let unsubscribeEmbed: (() => void) | undefined;

  function report(reply: { ok: boolean; error: string }) {
    if (!reply.ok) error = reply.error;
    return reply.ok;
  }

  async function refresh() {
    const dictionary = await dictionarySettings();
    if (report(dictionary) && dictionary.data) {
      provider = dictionary.data.provider;
      hasKrdictKey = dictionary.data.hasKey;
    }
    const youtube = await youtubeSettings();
    if (report(youtube) && youtube.data) hasYoutubeKey = youtube.data.saved;
  }

  onMount(() => {
    unsubscribeEmbed = loadEmbedSettings();
    void refresh();
  });
  onDestroy(() => unsubscribeEmbed?.());

  async function saveKrdict() {
    if (!report(await saveDictionaryKey(krdictKey))) return;
    krdictKey = "";
    await refresh();
  }

  async function chooseProvider(next: DictionaryProvider) {
    if (report(await selectDictionary(next))) provider = next;
  }

  async function saveYoutube() {
    if (!report(await saveYouTubeKey(youtubeKey))) return;
    youtubeKey = "";
    await refresh();
  }

  function toggleProvider(id: string) {
    embedSettings.update((settings) => ({
      ...settings,
      enabled: settings.enabled.includes(id)
        ? settings.enabled.filter((entry) => entry !== id)
        : [...settings.enabled, id],
    }));
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

  function addCustom() {
    if (!validCustomEmbed(customUrl)) {
      error = "Custom lookup URLs must be valid HTTPS templates.";
      return;
    }
    const id = `custom-${Date.now()}`;
    embedSettings.update((settings) => ({
      enabled: [...settings.enabled, id],
      custom: [...settings.custom, { id, url: customUrl }],
    }));
    customUrl = "";
  }

  function removeCustom(id: string) {
    embedSettings.update((settings) => ({
      enabled: settings.enabled.filter((entry) => entry !== id),
      custom: settings.custom.filter((entry) => entry.id !== id),
    }));
  }
</script>

<div class="flex max-w-3xl flex-col gap-6">
  {#if error}
    <p class="text-sm text-destructive" role="alert" data-testid="settings-error">{error}</p>
  {/if}

  <section class="flex flex-col gap-3" data-testid="appearance-settings">
    <h2 class="text-base font-semibold">Appearance</h2>
    <div class="flex flex-wrap gap-1" role="group" aria-label="Theme">
      {#each appearanceOptions as option (option.value)}
        <Button
          variant={ui.appearance === option.value ? "default" : "outline"}
          onclick={() => (ui.appearance = option.value)}
          data-testid={`settings-theme-${option.value}`}
        >
          {option.label}
        </Button>
      {/each}
    </div>
    <label class="flex flex-col gap-1 text-sm">
      <span>Zoom {Math.round(ui.pageScale * 100)}%</span>
      <input
        type="range"
        min="0.5"
        max="1.5"
        step="0.1"
        value={ui.pageScale}
        aria-label="Page zoom"
        oninput={(event) => (ui.pageScale = clampPageScale(Number(event.currentTarget.value)))}
      />
    </label>
    <label class="flex flex-col gap-1 text-sm">
      <span>Reading font</span>
      <select
        class="rounded-md border border-input bg-transparent px-2 py-1"
        bind:value={ui.readingFont}
      >
        <option value="noto">Noto Sans KR</option>
        <option value="inter">Inter</option>
      </select>
    </label>
    <label class="flex flex-col gap-1 text-sm">
      <span>Reader text size: {ui.readerTextSize}px</span>
      <input type="range" min="12" max="28" step="1" bind:value={ui.readerTextSize} />
    </label>
    <label class="flex flex-col gap-1 text-sm">
      <span>Reader line height: {ui.readerLineHeight}px</span>
      <input type="range" min="20" max="64" step="2" bind:value={ui.readerLineHeight} />
    </label>
    <label class="flex flex-col gap-1 text-sm">
      <span>Transcript line height: {ui.transcriptLineHeight}px</span>
      <input type="range" min="18" max="48" step="2" bind:value={ui.transcriptLineHeight} />
    </label>
  </section>

  <section class="flex flex-col gap-3" data-testid="dictionary-settings">
    <h2 class="text-base font-semibold">Dictionaries</h2>
    <label class="flex flex-col gap-1 text-sm">
      <span>Analysis provider</span>
      <select
        class="rounded-md border border-input bg-transparent px-2 py-1"
        value={provider}
        onchange={(event) => void chooseProvider(event.currentTarget.value as DictionaryProvider)}
      >
        <option value="wiktionary">Wiktionary</option>
        <option value="krdict">KRDict</option>
      </select>
    </label>
    {#if hasKrdictKey}
      <p class="text-sm text-muted-foreground">KRDict key saved locally.</p>
      <Button variant="outline" onclick={removeDictionaryKey}>Remove KRDict key</Button>
    {:else}
      <div class="flex flex-wrap gap-2">
        <Input
          class="max-w-sm"
          type="password"
          placeholder="32-character KRDict key"
          aria-label="KRDict API key"
          bind:value={krdictKey}
        />
        <Button variant="outline" onclick={saveKrdict}>Save KRDict key</Button>
      </div>
    {/if}
  </section>

  <section class="flex flex-col gap-3" data-testid="youtube-settings">
    <h2 class="text-base font-semibold">YouTube</h2>
    {#if hasYoutubeKey}
      <p class="text-sm text-muted-foreground">API key saved locally.</p>
      <Button variant="outline" onclick={removeYouTubeKey}>Remove YouTube key</Button>
    {:else}
      <div class="flex flex-wrap gap-2">
        <Input
          class="max-w-sm"
          type="password"
          placeholder="YouTube Data API key"
          aria-label="YouTube API key"
          bind:value={youtubeKey}
        />
        <Button variant="outline" onclick={saveYoutube}>Save YouTube key</Button>
      </div>
    {/if}
  </section>

  <section class="flex flex-col gap-3" data-testid="embed-settings">
    <h2 class="text-base font-semibold">Embedded lookup tabs</h2>
    <p class="text-sm text-muted-foreground">Drag to reorder. Disabled tabs stay installed.</p>
    {#each $embedSettings.enabled as id (id)}
      <div
        class="flex items-center gap-2 rounded-md border border-border bg-card p-2 text-sm"
        role="listitem"
        draggable="true"
        ondragstart={() => (dragged = id)}
        ondragover={(event) => event.preventDefault()}
        ondrop={() => reorder(id)}
      >
        <span class="cursor-grab">⋮⋮</span>
        <label class="flex flex-1 items-center gap-2">
          <input type="checkbox" checked onclick={() => toggleProvider(id)} />
          {embeddedProviders.find((provider) => provider.value === id)?.label ??
            $embedSettings.custom.find((entry) => entry.id === id)?.url ??
            id}
        </label>
        {#if id.startsWith("custom-")}
          <Button variant="ghost" onclick={() => removeCustom(id)}>Remove</Button>
        {/if}
      </div>
    {/each}
    <div class="flex flex-wrap gap-2">
      <Input
        class="max-w-md"
        placeholder="Custom HTTPS URL with a word placeholder"
        aria-label="Custom lookup URL"
        bind:value={customUrl}
      />
      <Button variant="outline" onclick={addCustom}>Add tab</Button>
    </div>
  </section>
</div>
