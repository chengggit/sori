<script lang="ts">
  import { ArrowLeft } from "@lucide/svelte";
  import { normalizeDisplayText } from "$lib/text";
  import { onMount } from "svelte";
  import HomePage from "./pages/HomePage.svelte";
  import HomeSearch from "$lib/home/HomeSearch.svelte";
  import AnalysisPage from "./dev/AnalysisPage.svelte";
  import AppShell from "$lib/components/AppShell.svelte";
  import BridgePage from "./dev/BridgePage.svelte";
  import HistoryPage from "./pages/HistoryPage.svelte";
  import LibraryPage from "./pages/LibraryPage.svelte";
  import ReaderPage from "./pages/ReaderPage.svelte";
  import SettingsPage from "./pages/SettingsPage.svelte";
  import VocabularyPage from "./pages/VocabularyPage.svelte";
  import WatchPage from "./pages/WatchPage.svelte";
  import ExplorePage from "./pages/ExplorePage.svelte";
  import { persistUi, ui } from "$lib/ui-state.svelte";
  import { startAutoHideScrollbars } from "$lib/scrollbars";

  let homeRequest = $state({ query: "", sequence: 0 });
  let route = $state(location.hash);
  let readerTitle = $state("");
  let systemDark = $state(window.matchMedia("(prefers-color-scheme: dark)").matches);

  const dark = $derived(ui.appearance === "dark" || (ui.appearance === "system" && systemDark));
  const path = $derived(route.replace(/^#\/?/, "").split("?")[0]);
  const page = $derived(path.split("/")[0] || "home");
  const readerId = $derived(Number(new URLSearchParams(route.split("?")[1] ?? "").get("id")) || 0);
  const watchId = $derived(readerId);
  const watchOrigin = $derived(new URLSearchParams(route.split("?")[1] ?? "").get("from"));
  const watchYouTubeId = $derived(new URLSearchParams(route.split("?")[1] ?? "").get("v") ?? "");

  $effect(() => {
    document.documentElement.classList.toggle("dark", dark);
    document.documentElement.style.zoom = String(ui.pageScale);
    document.documentElement.style.setProperty("--app-scale", String(ui.pageScale));
    persistUi();
  });

  function goTo(next: string) {
    location.hash = `#/${next}`;
    route = location.hash;
  }

  onMount(() => {
    const stopScrollbars = startAutoHideScrollbars();
    const onHashChange = () => {
      route = location.hash;
    };
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const onThemeChange = (event: MediaQueryListEvent) => {
      systemDark = event.matches;
    };
    window.addEventListener("hashchange", onHashChange);
    media.addEventListener("change", onThemeChange);
    return () => {
      stopScrollbars();
      window.removeEventListener("hashchange", onHashChange);
      media.removeEventListener("change", onThemeChange);
    };
  });
</script>

{#if route === "#bridge"}
  <BridgePage />
{:else if route === "#analysis"}
  <AnalysisPage />
{:else}
  <AppShell
    {page}
    appearance={ui.appearance}
    {dark}
    pageScale={ui.pageScale}
    onPage={goTo}
    onAppearance={(value) => (ui.appearance = value)}
    onScale={(value) => (ui.pageScale = value)}
    titleOverride={page === "reader"
      ? "Reader"
      : page === "watch"
        ? "Watch"
        : page === "settings"
          ? "Settings"
          : undefined}
  >
    {#snippet header()}
      {#if page === "reader"}
        <a href="#/library" class="flex shrink-0 items-center gap-2 text-sm text-muted-foreground">
          <ArrowLeft size={16} /> Library
        </a>
        <span class="truncate font-semibold" lang="ko">{normalizeDisplayText(readerTitle)}</span>
      {/if}
      {#if page === "home"}<HomeSearch
          onSearch={(query) => {
            homeRequest = { query, sequence: homeRequest.sequence + 1 };
          }}
        />{/if}
    {/snippet}
    {#if page === "home"}
      <HomePage request={homeRequest} />
    {:else if page === "library"}
      <LibraryPage />
    {:else if page === "reader"}
      {#key readerId}<ReaderPage
          documentId={readerId}
          onTitle={(title) => (readerTitle = title)}
        />{/key}
    {:else if page === "vocabulary"}
      <VocabularyPage />
    {:else if page === "watch"}
      {#key `${watchId}:${watchYouTubeId}`}<WatchPage
          videoId={watchId}
          youtubeId={watchYouTubeId}
          onBack={() =>
            goTo(
              watchOrigin === "history"
                ? "history"
                : watchYouTubeId
                  ? watchOrigin === "explore"
                    ? "explore"
                    : "home"
                  : "library",
            )}
        />{/key}
    {:else if page === "history"}
      <HistoryPage />
    {:else if page === "explore"}
      <ExplorePage />
    {:else if page === "settings"}
      <SettingsPage />
    {/if}
  </AppShell>
{/if}
