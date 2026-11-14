<script lang="ts">
  import { openUrl } from "@tauri-apps/plugin-opener";
  import { embeddedLookupUrl, embeddedProviders, type EmbeddedProvider } from "./embedded";

  let { provider, word, customUrl = "", label = "" }: { provider: EmbeddedProvider; word: string; customUrl?: string; label?: string } = $props();
  let searched = $state("");
  let loading = $state(true);
  let error = $state("");
  const name = $derived(label || embeddedProviders.find((item) => item.value === provider)?.label || "Dictionary");
  const url = $derived(embeddedLookupUrl(provider, searched || word, customUrl));

  $effect(() => {
    searched = word;
  });
  $effect(() => {
    // A provider or query change creates a fresh frame below.
    void url;
    loading = true;
    error = "";
  });

  async function openInBrowser() {
    try {
      await openUrl(url);
    } catch (cause) {
      error = String(cause);
    }
  }
</script>

<section aria-label={name} class="flex min-h-0 flex-1 flex-col">
  <div class="flex items-center justify-between gap-2 px-4 py-2 text-xs text-muted-foreground sm:px-5">
    <span role="status">{loading ? `Loading ${name}…` : name}</span>
    <button type="button" class="shrink-0 underline" onclick={openInBrowser}>Open in browser</button>
  </div>
  {#if error}<p role="alert" class="mb-2 px-4 text-sm text-destructive sm:px-5">{error}</p>{/if}
  <div class="min-h-0 flex-1 overflow-auto bg-white">
    {#if url}{#key url}
      <iframe
        title={`${name} lookup for ${searched || word}`}
        src={url}
        class="block min-h-0 min-w-full border-0 bg-white"
        style="height:100%;width:100%"
        sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-popups-to-escape-sandbox"
        referrerpolicy="no-referrer"
        onload={() => (loading = false)}
        onerror={() => {
          loading = false;
          error = `Couldn't load ${name}. Try opening it in your browser.`;
        }}
      ></iframe>
    {/key}{:else}<p class="p-4 text-sm text-muted-foreground">Set a valid HTTPS URL in Settings for this custom lookup.</p>{/if}
  </div>
</section>
