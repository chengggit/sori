<script lang="ts">
  import { onMount } from "svelte";
  import MediaHover from "$lib/components/media/MediaHover.svelte";
  import { fly } from "svelte/transition";
  import { Film, Link, Play, RefreshCw } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import VideoGrid from "$lib/youtube/VideoGrid.svelte";
  import VideoLinkDialog from "$lib/youtube/VideoLinkDialog.svelte";
  import { loadLibraryState } from "$lib/library/commands";
  import { Discovery } from "$lib/home/discovery.svelte";
  import { formatTime, recentVideo, watchLink, type ResumeEntry } from "$lib/home/resume";
  import { platform } from "../platform";

  let { request }: { request: { query: string; sequence: number } } = $props();
  const discovery = new Discovery();
  let recent = $state<ResumeEntry>();
  let libraryError = $state("");
  let linkOpen = $state(false);
  let thumbnailFailed = $state(false);
  let active = true;
  const progress = $derived(
    recent?.duration ? Math.min(100, Math.max(0, (recent.seconds / recent.duration) * 100)) : 0,
  );
  const thumbnail = $derived(
    recent?.youtubeId
      ? recent.thumbnailUrl
      : recent?.thumbnailUrl && recent.id
        ? `sori-thumbnail://video/${recent.id}.jpg`
        : "",
  );

  $effect(() => {
    void discovery.load(request.query);
  });
  onMount(() => {
    async function refresh() {
      const reply = await loadLibraryState();
      if (!active) return;
      libraryError = reply.error || reply.data?.error || "";
      recent = recentVideo(
        (reply.data?.videos ?? []) as ResumeEntry[],
        (reply.data?.youtubeHistory ?? []) as ResumeEntry[],
      );
      thumbnailFailed = false;
      if (recent?.id) {
        const result = await platform.invoke<ResumeEntry>("video:thumbnail", { id: recent.id });
        if (active && result.ok && result.data?.id === recent?.id) recent = result.data;
      }
    }
    void refresh();
    // Only refresh on returning to Home; thumbnail reads do not trigger mutations.
    return () => {
      active = false;
      discovery.destroy();
    };
  });
</script>

<section class="resume-hero" aria-labelledby="continue-heading">
  <h2 id="continue-heading" class="mb-4 text-xs font-semibold tracking-widest">CONTINUE WATCHING</h2>
  {#if libraryError}<p role="alert" class="mb-3 text-sm text-destructive">{libraryError}</p>{/if}
  {#if recent}
    <div data-media-focus class="resume-card" data-testid="resume-card">
      <div class="resume-thumbnail">
        <MediaHover>
          {#if thumbnail && !thumbnailFailed}<img
              src={thumbnail}
              alt=""
              onerror={() => (thumbnailFailed = true)}
            />{:else}<Film size={32} aria-hidden="true" />{/if}
        </MediaHover>
      </div>
      <div class="min-w-0 flex-1 py-3">
        <h3 class="truncate font-semibold">{recent.displayTitle || recent.title}</h3>
        <p class="mt-1 text-sm text-muted-foreground">
          {recent.youtubeId ? recent.channel || "YouTube" : "Local video"}
        </p>
        {#if recent.duration > 0}<progress
            class="resume-progress"
            value={progress}
            max="100"
            aria-label="Playback progress"
          >
            {Math.round(progress)}%
          </progress>{/if}
        <p class="mt-1 text-sm text-muted-foreground">
          {formatTime(recent.seconds)}{recent.duration > 0
            ? ` / ${formatTime(recent.duration)}`
            : " watched"}
        </p>
      </div>
      <a class="resume-button" href={watchLink(recent)}>
        <Play size={16} />{recent.seconds > 0 ? "Resume" : "Watch again"}
      </a>
    </div>
  {:else if !libraryError}
    <p class="mb-4 text-sm text-muted-foreground">
      Pick up where you left off. Your recent videos will appear here.
    </p>
    <a class="resume-button inline-flex" href="#/library">Open Library</a>
  {/if}
</section>

<section
  class="mt-6"
  aria-labelledby="discover-heading"
  aria-busy={discovery.loading || discovery.loadingMore}
>
  <div class="mb-5 flex flex-wrap items-end justify-between gap-4">
    <div>
      <p class="mb-1 text-xs font-medium tracking-widest text-muted-foreground">DISCOVER</p>
      <h2 id="discover-heading" class="text-2xl font-semibold">
        {discovery.query ? `Results for “${discovery.query}”` : "Korean videos on YouTube"}
      </h2>
    </div>
    <div class="flex gap-2">
      <Button
        variant="outline"
        size="sm"
        onclick={() => {
          linkOpen = true;
        }}
      >
        <Link size={15} />Paste YouTube link
      </Button>
      <Button variant="outline" size="sm" onclick={() => discovery.load(discovery.query)}>
        <RefreshCw size={15} />Refresh
      </Button>
    </div>
  </div>
  {#if discovery.error}<p role="alert" class="mb-4 text-sm text-destructive">{discovery.error}</p>{/if}
  {#if discovery.notice}<p class="text-sm text-muted-foreground" role="status">
      {discovery.notice}
      <a class="underline" href={discovery.hasKey ? "#/explore" : "#/settings"}>
        {discovery.hasKey ? "Explore" : "Open Settings"}
      </a>
    </p>{/if}
  <div class="relative">
    {#if discovery.loading || discovery.loadingMore}
      <div
        class="pointer-events-none absolute inset-0 z-10 grid place-items-center"
        aria-hidden="true"
        transition:fly={{ y: -12, duration: 180 }}
      >
        <span
          class="grid size-14 place-items-center rounded-full bg-white text-dashboard-accent shadow-lg"
        >
          <span class="refresh-spinner"></span>
        </span>
      </div>
    {/if}
    <VideoGrid videos={discovery.videos} />
  </div>
  {#if discovery.hasMore}<div class="mt-6 flex justify-center">
      <Button
        variant="outline"
        disabled={discovery.loading || discovery.loadingMore}
        onclick={() => discovery.load(discovery.query, true)}
      >
        {discovery.loadingMore ? "Loading…" : "Load more"}
      </Button>
    </div>{/if}
</section>

<VideoLinkDialog bind:open={linkOpen} />

<style>
  .resume-hero {
    padding: 28px;
    border: 1px solid var(--chip);
    border-radius: 20px;
    background: var(--hero);
    min-height: 248px;
  }
  .resume-card {
    display: flex;
    align-items: center;
    gap: 20px;
    padding-right: 20px;
    background: color-mix(in oklch, var(--card) 75%, transparent);
    border-radius: 12px;
  }
  .resume-thumbnail {
    width: 224px;
    aspect-ratio: 16 / 9;
    flex-shrink: 0;
    display: grid;
    place-items: center;
    position: relative;
    color: var(--dashboard-accent);
    background: var(--chip);
    border-radius: 12px;
    overflow: hidden;
  }
  .refresh-spinner {
    width: 26px;
    height: 26px;
    border: 3px solid color-mix(in oklch, var(--dashboard-accent) 25%, transparent);
    border-top-color: var(--dashboard-accent);
    border-radius: 50%;
    animation: refresh-spin 700ms linear infinite;
  }
  @keyframes refresh-spin {
    to {
      transform: rotate(360deg);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .refresh-spinner {
      animation-duration: 1.6s;
    }
  }
  .resume-progress {
    display: block;
    appearance: none;
    border: none;
    width: 100%;
    max-width: 512px;
    height: 8px;
    margin-top: 12px;
    border-radius: 8px;
    overflow: hidden;
    background: var(--chip);
  }
  .resume-progress::-webkit-progress-bar {
    background: var(--chip);
  }
  .resume-progress::-webkit-progress-value {
    background: var(--dashboard-progress);
    border-radius: 8px;
  }
  .resume-button {
    display: inline-flex;
    gap: 8px;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    min-width: 116px;
    padding: 8px 16px;
    background: var(--chip);
    color: var(--dashboard-accent);
    border-radius: 9px;
    font-size: 13px;
    font-weight: 600;
  }
  @media (max-width: 1000px) {
    .resume-thumbnail {
      width: 160px;
    }
  }
  @media (max-width: 600px) {
    .resume-hero {
      padding: 18px;
      min-height: auto;
    }
    .resume-card {
      flex-wrap: wrap;
      gap: 12px;
      padding: 12px;
    }
    .resume-thumbnail {
      width: 100%;
    }
    .resume-button {
      margin-left: auto;
    }
  }
</style>
