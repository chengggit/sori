<script lang="ts">
  import "./layout.css";
  import { onMount } from "svelte";
  import { isTauri } from "@tauri-apps/api/core";
  import { getCurrentWebview } from "@tauri-apps/api/webview";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import * as Sheet from "$lib/components/ui/sheet";
  import AppSidebar from "$lib/components/AppSidebar.svelte";
  import { embedSettings, loadEmbedSettings } from "$lib/features/dictionary/embed-settings";
  import { embeddedProviders, validCustomEmbed } from "$lib/features/dictionary/embedded";
  import { Plus, X } from "@lucide/svelte";

  let { children } = $props();
  let settingsOpen = $state(false);
  let theme = $state("system");
  let zoomError = $state("");
  let customUrl = $state("");
  let embedError = $state("");

  function addEmbed(event: SubmitEvent) {
    event.preventDefault();
    const url = customUrl.trim();
    if (!validCustomEmbed(url)) {
      embedError = "Enter a valid HTTPS URL.";
      return;
    }
    if ($embedSettings.custom.some((item) => item.url === url)) {
      embedError = "This URL is already in the list.";
      return;
    }
    const id = `custom-${crypto.randomUUID()}`;
    $embedSettings = {
      enabled: [...$embedSettings.enabled, id],
      custom: [...$embedSettings.custom, { id, url }],
    };
    customUrl = "";
    embedError = "";
  }

  function removeEmbed(id: string) {
    $embedSettings = {
      enabled: $embedSettings.enabled.filter((value) => value !== id),
      custom: $embedSettings.custom.filter((item) => item.id !== id),
    };
  }

  onMount(() => {
    return loadEmbedSettings();
  });

  onMount(() => {
    theme = localStorage.getItem("sori-theme") ?? "system";
    if (!isTauri()) return;
    let zoom = 1;
    let pending = Promise.resolve();
    const onZoomKey = (event: KeyboardEvent) => {
      if (!event.ctrlKey || !event.shiftKey || event.altKey || event.metaKey || event.isComposing)
        return;
      let next: number;
      switch (event.code) {
        case "Equal":
        case "NumpadAdd":
          next = zoom + 0.1;
          break;
        case "Minus":
        case "NumpadSubtract":
          next = zoom - 0.1;
          break;
        case "Digit0":
        case "Numpad0":
          next = 1;
          break;
        default:
          return;
      }
      event.preventDefault();
      zoom = Math.max(0.5, Math.min(2, Math.round(next * 10) / 10));
      const target = zoom;
      pending = pending
        .then(() => getCurrentWebview().setZoom(target))
        .then(
          () => {
            zoomError = "";
          },
          (cause) => {
            zoomError = `Could not change app zoom. ${String(cause)}`;
          },
        );
    };
    window.addEventListener("keydown", onZoomKey);
    return () => window.removeEventListener("keydown", onZoomKey);
  });

  $effect(() => {
    const preference = theme;
    const systemTheme = window.matchMedia("(prefers-color-scheme: dark)");
    const applyTheme = () => {
      document.documentElement.classList.toggle(
        "dark",
        preference === "dark" || (preference === "system" && systemTheme.matches),
      );
    };

    applyTheme();
    systemTheme.addEventListener("change", applyTheme);
    return () => systemTheme.removeEventListener("change", applyTheme);
  });
</script>

<svelte:window oncontextmenu={(event) => event.preventDefault()} />

{#if zoomError}<p
    role="alert"
    class="fixed right-4 bottom-4 z-50 rounded-md border bg-popover p-3 text-sm text-destructive"
  >
    {zoomError}
  </p>{/if}

<Sidebar.Provider style="--sidebar-width: 13rem;">
  <AppSidebar openSettings={() => (settingsOpen = true)} />

  <main class="min-w-0 flex-1">
    {@render children()}
  </main>
</Sidebar.Provider>

<Sheet.Root bind:open={settingsOpen}>
  <Sheet.Content>
    <Sheet.Header>
      <Sheet.Title>Settings</Sheet.Title>
      <Sheet.Description>Customize appearance and dictionary lookups.</Sheet.Description>
    </Sheet.Header>
    <div class="px-4">
      <label for="appearance" class="mb-2 block font-medium">Appearance</label>
      <select
        id="appearance"
        class="w-full rounded-md border bg-background px-3 py-2 focus-visible:outline-2"
        bind:value={theme}
        onchange={(event) => localStorage.setItem("sori-theme", event.currentTarget.value)}
      >
        <option value="system">System</option>
        <option value="light">Light</option>
        <option value="dark">Dark</option>
      </select>
    </div>
    <fieldset class="space-y-3 px-4 pb-6">
      <legend class="mb-3 font-medium">Embedded lookup tabs</legend>
      {#each embeddedProviders as provider}
        <label class="flex items-center gap-2 text-sm">
          <input type="checkbox" value={provider.value} bind:group={$embedSettings.enabled} />
          {provider.label}
        </label>
      {/each}
      {#each $embedSettings.custom as item (item.id)}
        <div class="flex items-center gap-2">
          <label class="flex min-w-0 flex-1 items-center gap-2 text-sm">
            <input type="checkbox" value={item.id} bind:group={$embedSettings.enabled} />
            <span class="truncate" title={item.url}>{new URL(item.url).hostname}</span>
          </label>
          <button type="button" class="rounded-md p-2 hover:bg-accent" aria-label={`Remove ${new URL(item.url).hostname}`} onclick={() => removeEmbed(item.id)}><X class="size-4" /></button>
        </div>
      {/each}
      <form class="flex gap-2" onsubmit={addEmbed}>
        <input aria-label="Custom embed URL" class="min-w-0 flex-1 rounded-md border bg-background px-3 py-2 text-sm" bind:value={customUrl} placeholder={"https://example.com/search?q={word}"} />
        <button type="submit" aria-label="Add custom embed" disabled={!customUrl.trim()} class="rounded-md border p-2 hover:bg-accent disabled:opacity-50"><Plus class="size-5" /></button>
      </form>
      <p class="text-xs text-muted-foreground">Use {"{word}"} for the selected word. HTTPS URLs are supported.</p>
      {#if embedError}
        <p role="alert" class="text-sm text-destructive">{embedError}</p>
      {/if}
    </fieldset>
  </Sheet.Content>
</Sheet.Root>
