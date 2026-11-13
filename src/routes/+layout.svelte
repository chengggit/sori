<script lang="ts">
  import "./layout.css";
  import { onMount } from "svelte";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import * as Sheet from "$lib/components/ui/sheet";
  import AppSidebar from "$lib/components/AppSidebar.svelte";

  let { children } = $props();
  let settingsOpen = $state(false);
  let theme = $state("system");

  onMount(() => {
    theme = localStorage.getItem("sori-theme") ?? "system";
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
