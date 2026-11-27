<script lang="ts">
  import { onMount } from "svelte";
  import { Film, Link, Play, RefreshCw } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import * as Sheet from "$lib/components/ui/sheet";
  import { loadLibraryState } from "$lib/library/commands";
  import { parseYouTubeLink } from "$lib/dashboard/youtube";
  import { Discovery } from "$lib/home/discovery.svelte";
  import { formatTime, recentVideo, watchLink, type ResumeEntry } from "$lib/home/resume";
  import { platform } from "../platform";

  let { request }: { request: { query: string; sequence: number } } = $props();
  const discovery = new Discovery();
  let recent = $state<ResumeEntry>();
  let libraryError = $state("");
  let linkOpen = $state(false);
  let link = $state("");
  let linkError = $state("");
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
  function openLink(event: SubmitEvent) {
    event.preventDefault();
    const id = parseYouTubeLink(link);
    if (!id) {
      linkError = "Paste a valid YouTube video link.";
      return;
    }
    location.hash = `#/explore?v=${id}`;
  }
</script>

{#snippet playOverlay()}
  <span class="thumbnail-overlay" aria-hidden="true">
    <span class="play-badge"><Play size={22} fill="currentColor" strokeWidth={1.5} /></span>
  </span>
{/snippet}

<section class="resume-hero" aria-labelledby="continue-heading">
  <h2 id="continue-heading" class="mb-4 text-xs font-semibold tracking-widest">CONTINUE WATCHING</h2>
  {#if libraryError}<p role="alert" class="mb-3 text-sm text-destructive">{libraryError}</p>{/if}
  {#if recent}
    <div class="resume-card" data-testid="resume-card">
      <div class="resume-thumbnail">
        {#if thumbnail && !thumbnailFailed}<img
            src={thumbnail}
            alt=""
            onerror={() => (thumbnailFailed = true)}
          />{:else}<Film size={32} aria-hidden="true" />{/if}
        {@render playOverlay()}
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
          linkError = "";
          linkOpen = true;
        }}
      >
        <Link size={15} />Paste YouTube link
      </Button>
      <Button
        variant="outline"
        size="sm"
        disabled={discovery.loading || discovery.loadingMore}
        onclick={() => discovery.load(discovery.query)}
      >
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
  {#if discovery.loading}<p role="status" class="mb-4 text-sm text-muted-foreground">
      Loading videos…
    </p>{/if}
  <div class="video-grid">
    {#each discovery.videos as video (video.id)}
      <a class="video-card" href={`#/explore?v=${video.id}`}>
        <div class="video-thumbnail">
          <img src={video.thumbnail} alt="" loading="lazy" referrerpolicy="no-referrer" />
          {@render playOverlay()}
        </div>
        <h3 class="mt-2 line-clamp-2 text-sm font-medium" title={video.title}>{video.title}</h3>
        <p class="mt-1 truncate text-xs text-muted-foreground">{video.channel}</p>
      </a>
    {/each}
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

<Sheet.Root bind:open={linkOpen}>
  <Sheet.Content>
    <Sheet.Header>
      <Sheet.Title>Paste YouTube link</Sheet.Title><Sheet.Description>
        Open an embeddable YouTube video. No API key is needed.
      </Sheet.Description>
    </Sheet.Header>
    <form class="space-y-3 px-4 pb-4" onsubmit={openLink}>
      <Input
        aria-label="YouTube link"
        placeholder="https://www.youtube.com/watch?v=…"
        bind:value={link}
        oninput={() => (linkError = "")}
      />
      {#if linkError}<p role="alert" class="text-sm text-destructive">{linkError}</p>{/if}
      <Button type="submit" disabled={!link.trim()}>Open video</Button>
    </form>
  </Sheet.Content>
</Sheet.Root>

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
  .resume-thumbnail img,
  .video-thumbnail img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    transition: transform 200ms ease;
  }
  .thumbnail-overlay {
    position: absolute;
    inset: 0;
    display: grid;
    place-items: center;
    background: color-mix(in oklch, black 38%, transparent);
    opacity: 0;
    transition: opacity 200ms ease;
    pointer-events: none;
  }
  .play-badge {
    display: grid;
    place-items: center;
    width: 46px;
    height: 46px;
    border-radius: 50%;
    background: #fff;
    color: var(--dashboard-accent);
    box-shadow: 0 2px 10px rgb(0 0 0 / 25%);
    transform: scale(0.82);
    transition: transform 200ms ease;
  }
  .resume-thumbnail:hover img,
  .video-thumbnail:hover img,
  .video-card:focus-visible img,
  .resume-card:has(.resume-button:focus-visible) img {
    transform: scale(1.03);
  }
  .resume-thumbnail:hover .thumbnail-overlay,
  .video-thumbnail:hover .thumbnail-overlay,
  .video-card:focus-visible .thumbnail-overlay,
  .resume-card:has(.resume-button:focus-visible) .thumbnail-overlay {
    opacity: 1;
  }
  .resume-thumbnail:hover .play-badge,
  .video-thumbnail:hover .play-badge,
  .video-card:focus-visible .play-badge,
  .resume-card:has(.resume-button:focus-visible) .play-badge {
    transform: scale(1);
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
  .video-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 26px 20px;
  }
  .video-card {
    min-width: 0;
  }
  .video-thumbnail {
    aspect-ratio: 16 / 9;
    position: relative;
    overflow: hidden;
    background: var(--chip);
    border-radius: 12px;
  }
  @media (max-width: 1250px) {
    .video-grid {
      grid-template-columns: repeat(3, minmax(0, 1fr));
    }
  }
  @media (max-width: 1000px) {
    .video-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
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
    .video-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
