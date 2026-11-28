<script lang="ts">
  import { onMount } from "svelte";
  import { Film } from "@lucide/svelte";
  import MediaHover from "$lib/components/media/MediaHover.svelte";
  import { formatTime } from "$lib/video/time";
  import { normalizeDisplayText } from "$lib/text";
  import { historyLink, historyThumbnail, type HistoryEntry } from "./entries";
  let {
    entry,
    opening,
    onOpen,
    onVisible,
    onArtworkError,
    artworkVersion = 0,
  }: {
    entry: HistoryEntry;
    opening: boolean;
    onOpen: (event: MouseEvent) => void;
    onVisible: () => void;
    onArtworkError: () => void;
    artworkVersion?: number;
  } = $props();
  let row: HTMLAnchorElement;
  let failed = $state(false);
  const thumbnail = $derived(historyThumbnail(entry));
  const title = $derived(normalizeDisplayText(entry.displayTitle || entry.title || "Untitled"));
  const progress = $derived(
    entry.duration > 0 ? Math.min(100, Math.max(0, (entry.seconds / entry.duration) * 100)) : 0,
  );
  $effect(() => {
    thumbnail;
    artworkVersion;
    failed = false;
  });
  onMount(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((item) => item.isIntersecting)) {
          observer.disconnect();
          onVisible();
        }
      },
      { root: document.querySelector('[data-testid="page-content"]'), rootMargin: "200px" },
    );
    observer.observe(row);
    return () => observer.disconnect();
  });
</script>

<a
  bind:this={row}
  data-media-focus
  class="history-row"
  href={historyLink(entry)}
  onclick={onOpen}
  data-testid={`history-${entry.key}`}
  aria-busy={opening}
>
  <div class="thumbnail">
    <MediaHover>
      {#if thumbnail && !failed}<img
          src={thumbnail}
          alt=""
          loading="lazy"
          referrerpolicy="no-referrer"
          onerror={() => {
            failed = true;
            onArtworkError();
          }}
        />{:else}<Film size={28} aria-hidden="true" />{/if}
    </MediaHover>
    {#if entry.duration > 0}<span class="duration">{formatTime(entry.duration)}</span><span
        class="progress"
        role="progressbar"
        aria-label={`Progress for ${title}`}
        aria-valuenow={Math.round(progress)}
        aria-valuemin={0}
        aria-valuemax={100}
      >
        <span style:width={`${progress}%`}></span>
      </span>{/if}
  </div>
  <div class="details">
    <h2 {title} lang="ko">{title}</h2>
    {#if entry.channel}<p class="channel">{normalizeDisplayText(entry.channel)}</p>{/if}
    <p class:sr-only={entry.duration > 0} class="position">
      {entry.seconds > 0
        ? `${formatTime(entry.seconds)}${entry.duration > 0 ? ` / ${formatTime(entry.duration)}` : " watched"}`
        : "Watched"}
    </p>
    {#if opening}<p class="position" role="status">Opening video…</p>{/if}
  </div>
</a>

<style>
  .history-row {
    display: flex;
    align-items: flex-start;
    gap: 16px;
    border-radius: 8px;
    min-width: 0;
  }
  .thumbnail {
    width: 40%;
    max-width: 268px;
    aspect-ratio: 16/9;
    position: relative;
    flex-shrink: 0;
    overflow: hidden;
    border-radius: 8px;
    background: var(--chip);
    color: var(--muted-foreground);
  }
  .duration {
    position: absolute;
    right: 4px;
    bottom: 8px;
    padding: 1px 4px;
    border-radius: 4px;
    background: #000c;
    color: white;
    font-size: 12px;
    line-height: 16px;
    font-variant-numeric: tabular-nums;
  }
  .progress {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    height: 4px;
    background: #0006;
  }
  .progress span {
    display: block;
    height: 100%;
    background: var(--dashboard-progress);
  }
  .details {
    min-width: 0;
    flex: 1;
    padding-top: 2px;
  }
  h2 {
    font-size: 16px;
    line-height: 22px;
    font-weight: 600;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    overflow-wrap: anywhere;
  }
  .history-row:hover h2,
  .history-row:focus-visible h2 {
    text-decoration: underline;
  }
  .channel {
    margin-top: 6px;
    color: var(--muted-foreground);
    font-size: 14px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .position {
    margin-top: 4px;
    font-size: 12px;
    color: var(--muted-foreground);
    font-variant-numeric: tabular-nums;
  }
  @media (max-width: 480px) {
    .history-row {
      gap: 12px;
    }
    h2 {
      font-size: 14px;
      line-height: 20px;
    }
    .channel {
      font-size: 12px;
      margin-top: 4px;
    }
  }
</style>
