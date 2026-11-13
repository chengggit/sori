<script lang="ts">
  import { onMount } from "svelte";
  import { ExternalLink, Play, RefreshCw, Search } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import { parseYouTubeLink, searchYouTube, type YouTubeVideo } from "$lib/features/dashboard/youtube";

  const key = import.meta.env.VITE_YOUTUBE_API_KEY?.trim();
  const discoveryTopics = [
    "한국어 브이로그 한국어 자막",
    "한국 여행 브이로그 한국어 자막",
    "집밥 요리 한국어 자막",
    "한국 일상 인터뷰 한국어 자막",
    "한국 문화 다큐멘터리 한국어 자막",
  ];
  let topicIndex = Math.floor(Math.random() * discoveryTopics.length);
  let activeQuery = discoveryTopics[topicIndex];
  let search = $state("");
  let link = $state("");
  let linkError = $state("");
  let searchError = $state("");
  let loading = $state(false);
  let videos = $state<YouTubeVideo[]>([]);
  let selected = $state<{ id: string; title: string }>();
  let player = $state<HTMLElement>();
  let searchInput = $state<HTMLInputElement | null>(null);
  let request: AbortController | undefined;
  let tooltipVideoId = $state<string | null>(null);
  let tooltipTimer: ReturnType<typeof setTimeout> | undefined;

  onMount(() => {
    if (key) void loadVideos();
    return () => request?.abort();
  });

  async function loadVideos(query = activeQuery) {
    if (!key) return;
    activeQuery = query;
    request?.abort();
    const current = new AbortController();
    request = current;
    loading = true;
    searchError = "";
    videos = [];

    try {
      const results = await searchYouTube(key, query, current.signal);
      if (!current.signal.aborted) videos = results;
    } catch (error) {
      if (!current.signal.aborted) {
        searchError =
          error instanceof TypeError
            ? "Could not connect to YouTube. Try again."
            : error instanceof Error
              ? error.message
              : "Could not load YouTube videos.";
      }
    } finally {
      if (request === current) loading = false;
    }
  }

  function refreshDiscover() {
    topicIndex = (topicIndex + 1) % discoveryTopics.length;
    search = "";
    void loadVideos(discoveryTopics[topicIndex]);
  }

  function openVideo(id: string, title: string) {
    selected = { id, title };
    player?.scrollIntoView({ block: "start" });
  }

  function startTitleTooltip(id: string) {
    if (tooltipVideoId === id) return;
    if (tooltipTimer) clearTimeout(tooltipTimer);
    tooltipVideoId = null;
    tooltipTimer = setTimeout(() => {
      tooltipVideoId = id;
      tooltipTimer = undefined;
    }, 1500);
  }

  function stopTitleTooltip(id: string) {
    if (tooltipTimer) {
      clearTimeout(tooltipTimer);
      tooltipTimer = undefined;
    }
    if (tooltipVideoId === id) tooltipVideoId = null;
  }

  function openLink() {
    const id = parseYouTubeLink(link);
    linkError = id ? "" : "Enter a valid YouTube video link.";
    if (id) openVideo(id, "YouTube video");
  }

  function handleShortcut(event: KeyboardEvent) {
    if (key && (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault();
      searchInput?.focus();
    }
  }
</script>

<svelte:head>
  <title>Home · Sori</title>
  <meta name="description" content="Discover Korean media in Sori." />
</svelte:head>

<svelte:window onkeydown={handleShortcut} />

<header class="flex min-h-[70px] items-center gap-3 border-b px-4 sm:px-8">
  <Sidebar.Trigger class="md:hidden" />
  {#if key}
    <form
      class="ml-11 flex w-full max-w-[504px] items-center gap-2 sm:ml-[52px]"
      onsubmit={(event) => {
        event.preventDefault();
        void loadVideos(search.trim() || discoveryTopics[topicIndex]);
      }}
    >
      <Input
        bind:ref={searchInput}
        bind:value={search}
        aria-label="Search YouTube"
        placeholder="Search YouTube for Korean videos"
        class="h-[38px] rounded-xl bg-card"
      />
      <Button type="submit" size="icon" variant="outline" aria-label="Search YouTube"><Search /></Button
      >
    </form>
  {:else}
    <h1 class="font-semibold">Home</h1>
  {/if}
</header>

<div class="mx-auto max-w-[1600px] px-4 pt-7 pb-10 sm:px-8 lg:pr-10">
  <section
    bind:this={player}
    aria-labelledby="watch-heading"
    class="rounded-[20px] border border-dashboard-chip bg-dashboard-hero p-5 sm:p-7"
  >
    <h2 id="watch-heading" class="text-lg font-semibold">Watch on YouTube</h2>
    <form
      class="mt-3 flex max-w-xl flex-wrap gap-2"
      onsubmit={(event) => {
        event.preventDefault();
        openLink();
      }}
    >
      <Input
        bind:value={link}
        aria-label="YouTube video link"
        placeholder="Paste a YouTube video link"
        class="min-w-44 flex-1 bg-card"
      />
      <Button type="submit"><Play /> Open video</Button>
    </form>
    {#if linkError}<p class="mt-2 text-sm text-destructive" role="alert">{linkError}</p>{/if}

    {#if selected}
      <div class="mt-5 max-w-4xl">
        <div class="mb-2 flex flex-wrap items-center justify-between gap-2">
          <h3 class="font-medium">{selected.title}</h3>
          <Button
            href={`https://www.youtube.com/watch?v=${selected.id}`}
            target="_blank"
            rel="noopener"
            variant="outline"
            size="sm"
          >
            Open on YouTube <ExternalLink />
          </Button>
        </div>
        {#key selected.id}
          <iframe
            class="aspect-video min-h-[200px] w-full rounded-xl bg-black"
            title={selected.title}
            src={`https://www.youtube.com/embed/${selected.id}?cc_lang_pref=ko`}
            referrerpolicy="strict-origin-when-cross-origin"
            allow="encrypted-media; picture-in-picture; fullscreen"
            allowfullscreen
          ></iframe>
        {/key}
      </div>
    {/if}
  </section>

  <section id="discover" aria-labelledby="discover-heading" class="mt-6">
    <div class="flex flex-wrap items-end justify-between gap-3">
      <div>
        <p class="mb-0.5 text-[11px] font-semibold tracking-[0.07em] text-muted-foreground uppercase">
          Discover
        </p>
        <h2 id="discover-heading" class="text-2xl font-semibold tracking-tight">
          Korean videos on YouTube
        </h2>
      </div>
      {#if key}
        <Button variant="outline" size="sm" disabled={loading} onclick={refreshDiscover}>
          <RefreshCw />
          Refresh Discover
        </Button>
      {/if}
    </div>

    {#if !key}
      <p class="mt-3 text-sm text-muted-foreground">
        YouTube search requires a configured API key. You can still open a video from its link.
      </p>
    {:else if loading}
      <p class="mt-4 text-sm text-muted-foreground" role="status">Loading YouTube videos…</p>
    {:else if searchError}
      <p class="mt-4 text-sm text-destructive" role="alert">{searchError}</p>
      <Button variant="outline" class="mt-2" onclick={() => void loadVideos()}>Retry</Button>
    {:else if videos.length === 0}
      <p class="mt-4 text-sm text-muted-foreground">
        No embeddable videos found. Try a different search.
      </p>
    {:else}
      <div
        class="mt-5 grid grid-cols-1 gap-x-5 gap-y-7 min-[480px]:grid-cols-2 min-[1080px]:grid-cols-3 min-[1280px]:grid-cols-4"
      >
        {#each videos as video (video.id)}
          <button
            type="button"
            class="group min-w-0 rounded-xl text-left focus-visible:outline-2 focus-visible:outline-ring"
            onclick={() => openVideo(video.id, video.title)}
          >
            <span class="relative block aspect-video overflow-hidden rounded-xl bg-muted">
              <img
                src={video.thumbnail}
                alt=""
                loading="lazy"
                class="size-full object-cover transition duration-200 ease-out group-hover:scale-[1.02] group-hover:brightness-75 motion-reduce:transition-none"
              />
              <span
                class="pointer-events-none absolute inset-0 grid place-items-center bg-black/0 transition duration-200 group-hover:bg-black/10 motion-reduce:transition-none"
              >
                <span
                  class="grid size-10 scale-90 place-items-center rounded-full bg-white/90 text-dashboard-accent opacity-0 shadow-sm transition duration-200 group-hover:scale-100 group-hover:opacity-100 motion-reduce:transition-none"
                >
                  <Play class="ml-0.5 size-4 fill-current" />
                </span>
              </span>
            </span>
            <span
              role="presentation"
              class="relative mt-2 block"
              onpointerenter={() => startTitleTooltip(video.id)}
              onpointerleave={() => stopTitleTooltip(video.id)}
            >
              <span class="video-title block text-sm leading-5 font-semibold">{video.title}</span>
              {#if tooltipVideoId === video.id}
                <span
                  role="tooltip"
                  class="absolute bottom-full left-0 z-50 mb-2 max-w-xs rounded-md bg-foreground px-3 py-1.5 text-xs text-background shadow-lg"
                >
                  {video.title}
                </span>
              {/if}
            </span>
            <span class="block text-xs text-muted-foreground">{video.channel}</span>
          </button>
        {/each}
      </div>
    {/if}
  </section>
</div>

<style>
  .video-title {
    min-height: 2.5rem;
    display: -webkit-box;
    overflow: hidden;
    -webkit-box-orient: vertical;
    line-clamp: 2;
    -webkit-line-clamp: 2;
  }
</style>
