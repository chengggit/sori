<script lang="ts">
  import "./layout.css";
  import { onMount } from "svelte";
  import { isTauri } from "@tauri-apps/api/core";
  import { getCurrentWebview } from "@tauri-apps/api/webview";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import * as Sheet from "$lib/components/ui/sheet";
  import AppSidebar from "$lib/components/AppSidebar.svelte";

  let { children } = $props();
  let settingsOpen = $state(false);
  let theme = $state("system");
  let zoomError = $state("");

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
      <Sheet.Description>Customize Sori’s appearance.</Sheet.Description>
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
  </Sheet.Content>
</Sheet.Root>
