<script lang="ts">
  import type { Snippet } from "svelte";
  import AppSidebar from "./AppSidebar.svelte";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import * as Sheet from "$lib/components/ui/sheet";
  import { appearanceOptions, clampPageScale, type Appearance } from "$lib/appearance";

  let {
    page,
    appearance,
    dark,
    pageScale,
    onPage,
    onAppearance,
    onScale,
    titleOverride,
    children,
    header,
  }: {
    page: string;
    appearance: Appearance;
    dark: boolean;
    pageScale: number;
    onPage: (page: string) => void;
    onAppearance: (value: Appearance) => void;
    onScale: (value: number) => void;
    titleOverride?: string;
    children?: Snippet;
    header?: Snippet;
  } = $props();

  let open = $state(localStorage.getItem("sori-sidebar-collapsed") !== "true");
  let appearanceOpen = $state(false);
  const titles: Record<string, string> = {
    home: "Home",
    explore: "Explore",
    library: "My Library",
    history: "History",
    vocabulary: "Vocabulary",
    settings: "Settings",
  };
  const title = $derived(titleOverride ?? titles[page] ?? "Home");
  $effect(() => localStorage.setItem("sori-sidebar-collapsed", String(!open)));

  function onZoomKey(event: KeyboardEvent) {
    if (!(event.ctrlKey || event.metaKey) || !event.shiftKey || event.altKey || event.isComposing)
      return;
    const direction = ["Equal", "NumpadAdd"].includes(event.code)
      ? 1
      : ["Minus", "NumpadSubtract"].includes(event.code)
        ? -1
        : 0;
    if (!direction && !["Digit0", "Numpad0"].includes(event.code)) return;
    event.preventDefault();
    onScale(direction ? clampPageScale(Math.round((pageScale + direction * 0.1) * 10) / 10) : 1);
  }
</script>

<svelte:window onkeydown={onZoomKey} />

<Sidebar.Provider
  bind:open
  style="--sidebar-width: 13rem;"
  class="h-(--app-height) min-h-0 overflow-hidden"
>
  <AppSidebar
    {page}
    openSettings={() => onPage("settings")}
    openAppearance={() => (appearanceOpen = true)}
  />
  <main data-testid="page-content" class="min-w-0 flex-1 overflow-auto">
    <header class="sticky top-0 z-10 border-b border-border bg-background">
      <div
        class="mx-auto flex h-14 items-center gap-2 px-4 sm:px-8"
        class:home-width={page === "home"}
        class:max-w-6xl={page !== "home"}
      >
        <Sidebar.Trigger class="md:hidden" />
        <h1 data-testid="page-title" class="text-lg font-semibold" class:sr-only={page === "home"}>
          {title}
        </h1>
        {#if page === "home"}{@render header?.()}{/if}
      </div>
    </header>
    <div
      class="mx-auto px-4 py-6 sm:px-8"
      class:home-width={page === "home"}
      class:max-w-6xl={page !== "home"}
    >
      {@render children?.()}
    </div>
  </main>
</Sidebar.Provider>

<Sheet.Root bind:open={appearanceOpen}>
  <Sheet.Content>
    <Sheet.Header>
      <Sheet.Title>Appearance</Sheet.Title>
      <Sheet.Description>Choose a theme and adjust the size of the app.</Sheet.Description>
    </Sheet.Header>
    <div class="space-y-6 px-4 pb-4">
      <fieldset class="space-y-3">
        <legend class="font-medium">Theme</legend>
        <div class="flex gap-2">
          {#each appearanceOptions as option (option.value)}
            <button
              type="button"
              data-testid={`theme-${option.value}`}
              aria-pressed={appearance === option.value}
              class="rounded-lg border border-border px-3 py-2 hover:bg-neutral-hover aria-pressed:bg-accent-soft"
              onclick={() => onAppearance(option.value)}
            >
              {option.label}
            </button>
          {/each}
        </div>
        <p data-testid="theme-state" class="text-sm text-muted-foreground">{dark ? "Dark" : "Light"}</p>
      </fieldset>
      <label class="flex flex-col gap-3 text-sm">
        <span>App zoom · {Math.round(pageScale * 100)}%</span>
        <input
          type="range"
          min="0.5"
          max="1.5"
          step="0.1"
          value={pageScale}
          aria-label="App zoom"
          oninput={(event) => onScale(clampPageScale(Number(event.currentTarget.value)))}
        />
      </label>
      <p class="text-xs text-muted-foreground">
        Ctrl/Cmd + Shift + Plus or Minus to zoom. Ctrl/Cmd + Shift + 0 to reset.
      </p>
    </div>
  </Sheet.Content>
</Sheet.Root>

<style>
  .home-width {
    max-width: 1592px;
  }
</style>
