<script lang="ts">
  import { onMount } from "svelte";
  import { goto } from "$app/navigation";
  import { resolve } from "$app/paths";
  import { Link, Play, RefreshCw, Search } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import * as Sheet from "$lib/components/ui/sheet";
  import {
    formatPlaybackTime,
    readProgress,
    saveProgress,
    type Playback,
  } from "$lib/features/dashboard/playback";
  import {
    fetchYouTubeDuration,
    fetchYouTubeMetadata,
    parseYouTubeLink,
    searchYouTube,
    type YouTubeVideo,
  } from "$lib/features/dashboard/youtube";

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
  let history = $state<Playback>();
  let linkOpen = $state(false);
  let searchInput = $state<HTMLInputElement | null>(null);
  let request: AbortController | undefined;
  let nextPageToken = $state<string>();
  let loadingMore = $state(false);
  let discoverEnd = $state<HTMLDivElement | null>(null);
  let tooltipVideoId = $state<string | null>(null);
  let tooltipTimer: ReturnType<typeof setTimeout> | undefined;

  onMount(() => {
    history = readProgress();
    const durationRequest = new AbortController();
    const video = history;
    if (video && !video.channel) {
      void fetchYouTubeMetadata(video.id, durationRequest.signal)
        .then((details) => {
          const saved = readProgress();
          if (durationRequest.signal.aborted || !details?.channel || saved?.id !== video.id) return;
          history = { ...saved, channel: details.channel };
          saveProgress(history, history.seconds);
        })
        .catch(() => {});
    }
    if (
      key &&
      video &&
      !(video.duration && Number.isFinite(video.duration) && video.duration >= video.seconds)
    ) {
      void fetchYouTubeDuration(key, video.id, durationRequest.signal)
        .then((duration) => {
          if (durationRequest.signal.aborted || !duration || duration < video.seconds) return;
          const saved = readProgress();
          if (saved?.id === video.id && saved.seconds === video.seconds) {
            history = { ...saved, duration };
            saveProgress(history, video.seconds);
          }
        })
        .catch(() => {});
    }
    if (key) void loadVideos();
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && key && nextPageToken && !loading && !loadingMore)
          void loadMoreVideos();
      },
      { rootMargin: "500px" },
    );
    if (discoverEnd) observer.observe(discoverEnd);
    return () => {
      durationRequest.abort();
      request?.abort();
      observer.disconnect();
    };
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
    nextPageToken = undefined;

    try {
      const results = await searchYouTube(key, query, current.signal);
      if (!current.signal.aborted) {
        videos = results.videos;
        nextPageToken = results.nextPageToken;
      }
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

  async function loadMoreVideos() {
    if (!key || !nextPageToken || loadingMore) return;
    const current = new AbortController();
    request = current;
    loadingMore = true;
    try {
      const results = await searchYouTube(key, activeQuery, current.signal, nextPageToken);
      if (!current.signal.aborted) {
        videos = [
          ...videos,
          ...results.videos.filter((video) => !videos.some((item) => item.id === video.id)),
        ];
        nextPageToken = results.nextPageToken;
      }
    } catch {
      // Keep the loaded rows if a later page cannot be fetched.
    } finally {
      if (request === current) loadingMore = false;
    }
  }

  function refreshDiscover() {
    topicIndex = (topicIndex + 1) % discoveryTopics.length;
    search = "";
    void loadVideos(discoveryTopics[topicIndex]);
  }

  function watchUrl(id: string, title?: string, channel?: string) {
    const params = new URLSearchParams({ v: id });
    if (title) params.set("title", title);
    if (channel) params.set("channel", channel);
    return resolve("/watch") + "?" + params;
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
    if (id) {
      linkOpen = false;
      link = "";
      void goto(watchUrl(id));
    }
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

<header class="flex h-14 items-center gap-3 border-b px-4 sm:px-8">
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
  {#if history}
    {@const video = history}
    {@const duration =
      video.duration && Number.isFinite(video.duration) && video.duration >= video.seconds
        ? video.duration
        : undefined}
    <section
      aria-labelledby="continue-heading"
      class="mb-6 rounded-[20px] border border-dashboard-chip bg-dashboard-hero p-5 sm:p-7"
    >
      <h2 id="continue-heading" class="text-xs font-semibold tracking-widest uppercase">
        Continue watching
      </h2>
      <div
        class="mt-4 flex flex-col gap-4 overflow-hidden rounded-xl bg-card/75 sm:flex-row sm:items-center sm:gap-5"
      >
        <img
          src={`https://i.ytimg.com/vi/${video.id}/mqdefault.jpg`}
          alt=""
          class="aspect-video w-full shrink-0 rounded-xl bg-muted object-cover sm:w-52 xl:w-56"
        />
        <div class="min-w-0 flex-1 px-4 sm:px-0 sm:py-3">
          <p class="clamped-title max-w-lg font-semibold wrap-break-word" title={video.title}>
            {video.title}
          </p>
          {#if video.channel}
            <p class="mt-1 text-sm text-muted-foreground">{video.channel}</p>
          {/if}
          {#if duration}
            <progress
              class="watch-progress mt-3 block h-2 w-full max-w-lg overflow-hidden rounded-full bg-dashboard-chip"
              aria-label="Playback progress"
              value={video.seconds}
              max={duration}
            ></progress>
          {/if}
          <p class="mt-1 text-sm text-muted-foreground">
            {formatPlaybackTime(video.seconds)}{duration
              ? ` / ${formatPlaybackTime(duration)}`
              : " watched"}
          </p>
        </div>
        <Button
          href={watchUrl(video.id, video.title, video.channel)}
          class="mx-4 mb-4 self-start rounded-xl px-5 sm:my-0 sm:mr-5 sm:ml-0 sm:self-center"
          ><Play /> Resume</Button
        >
      </div>
      <div bind:this={discoverEnd} class="h-8" aria-hidden="true">
        {#if loadingMore}<p class="py-4 text-center text-sm text-muted-foreground">
            Loading more videos…
          </p>{/if}
      </div>
    </section>
  {/if}

  <section id="discover" aria-labelledby="discover-heading">
    <div class="flex flex-wrap items-end justify-between gap-3">
      <div>
        <p class="mb-0.5 text-[11px] font-semibold tracking-[0.07em] text-muted-foreground uppercase">
          Discover
        </p>
        <h2 id="discover-heading" class="text-2xl font-semibold tracking-tight">
          Korean videos on YouTube
        </h2>
      </div>
      <div class="flex flex-wrap gap-2">
        <Button
          variant="outline"
          size="sm"
          onclick={() => {
            linkError = "";
            linkOpen = true;
          }}
        >
          <Link /> Paste YouTube link
        </Button>
        {#if key}
          <Button variant="outline" size="sm" disabled={loading} onclick={refreshDiscover}>
            <RefreshCw />
            Refresh Discover
          </Button>
        {/if}
      </div>
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
          <a
            class="group min-w-0 rounded-xl text-left focus-visible:outline-2 focus-visible:outline-ring"
            href={watchUrl(video.id, video.title, video.channel)}
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
              <span class="clamped-title min-h-10 text-sm leading-5 font-semibold">{video.title}</span>
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
          </a>
        {/each}
      </div>
    {/if}
  </section>
</div>

<Sheet.Root bind:open={linkOpen}>
  <Sheet.Content>
    <Sheet.Header>
      <Sheet.Title>Open a YouTube video</Sheet.Title>
      <Sheet.Description>Paste a video link to watch it in Sori.</Sheet.Description>
    </Sheet.Header>
    <form
      class="space-y-3 px-4"
      onsubmit={(event) => {
        event.preventDefault();
        openLink();
      }}
    >
      <Input
        bind:value={link}
        aria-label="YouTube video link"
        placeholder="Paste a YouTube video link"
      />
      {#if linkError}<p class="text-sm text-destructive" role="alert">{linkError}</p>{/if}
      <Button type="submit"><Play /> Open video</Button>
    </form>
  </Sheet.Content>
</Sheet.Root>

<style>
  .watch-progress {
    appearance: none;
  }

  .watch-progress::-webkit-progress-bar {
    background: var(--dashboard-chip);
    border-radius: 999px;
  }

  .watch-progress::-webkit-progress-value {
    background: var(--dashboard-progress);
    border-radius: 999px;
  }

  .watch-progress::-moz-progress-bar {
    background: var(--dashboard-progress);
    border-radius: 999px;
  }

  .clamped-title {
    display: -webkit-box;
    overflow: hidden;
    -webkit-box-orient: vertical;
    line-clamp: 2;
    -webkit-line-clamp: 2;
  }
</style>
