<script lang="ts">
  import { onMount } from "svelte";
  import { resolve } from "$app/paths";
  import { Button } from "$lib/components/ui/button";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import {
    formatPlaybackTime,
    readWatchHistory,
    type WatchHistoryEntry,
  } from "$lib/features/dashboard/playback";

  let history = $state<WatchHistoryEntry[]>();

  onMount(() => {
    history = readWatchHistory();
  });
</script>

<svelte:head>
  <title>History · Sori</title>
</svelte:head>

<header class="border-b">
  <div class="mx-auto flex h-14 max-w-6xl items-center gap-2 px-4 sm:px-8">
    <Sidebar.Trigger class="md:hidden" />
    <h1 class="text-lg font-semibold">History</h1>
  </div>
</header>

<div class="mx-auto max-w-6xl px-4 py-6 sm:px-8">
  {#if history?.length}
    <ul class="space-y-4">
      {#each history as video (video.id)}
        {@const duration = video.duration}
        {@const progress = video.completed
          ? 100
          : duration && duration > 0
            ? Math.min(100, (video.seconds / duration) * 100)
            : undefined}
        {@const query = new URLSearchParams({
          v: video.id,
          title: video.title,
          channel: video.channel ?? "",
        })}
        <li>
          <a
            href={resolve(`/watch?${query}`)}
            class="group flex items-start gap-3 rounded-lg focus-visible:outline-2 focus-visible:outline-offset-4 sm:gap-4"
          >
            <div
              class="relative aspect-video w-2/5 max-w-[268px] shrink-0 overflow-hidden rounded-lg bg-muted"
            >
              <img
                src={`https://i.ytimg.com/vi/${video.id}/mqdefault.jpg`}
                alt=""
                loading="lazy"
                class="size-full object-cover"
              />
              {#if duration && duration > 0}
                <span class="absolute right-1 bottom-2 rounded bg-black/80 px-1 text-xs text-white">
                  {formatPlaybackTime(duration)}
                </span>
              {/if}
              {#if progress !== undefined}
                <div class="absolute inset-x-0 bottom-0 h-1 bg-black/40" aria-hidden="true">
                  <div class="h-full bg-dashboard-progress" style:width={`${progress}%`}></div>
                </div>
              {/if}
            </div>
            <div class="min-w-0 flex-1 py-0.5">
              <h2
                class="line-clamp-2 text-sm leading-snug font-semibold wrap-break-word group-hover:underline sm:text-base"
                title={video.title}
              >
                {video.title}
              </h2>
              {#if video.channel}
                <p class="mt-1 truncate text-sm text-muted-foreground sm:mt-2">{video.channel}</p>
              {/if}
              <p class={progress === undefined ? "mt-1 text-xs text-muted-foreground" : "sr-only"}>
                {video.completed ? "Watched" : `${formatPlaybackTime(video.seconds)} watched`}
              </p>
            </div>
          </a>
        </li>
      {/each}
    </ul>
  {:else if history}
    <div class="rounded-xl border bg-card p-6">
      <h2 class="font-semibold">No watch history yet</h2>
      <p class="mt-1 text-sm text-muted-foreground">Videos you play in Sori will appear here.</p>
      <Button href={resolve("/explore")} variant="outline" class="mt-4">Explore videos</Button>
    </div>
  {/if}
</div>
