<script lang="ts">
  import { convertFileSrc } from "@tauri-apps/api/core";
  import { onMount } from "svelte";
  import type { PlaybackEvents } from "./playback";

  let {
    path,
    playbackUrl,
    title,
    start,
    events,
  }: {
    path: string;
    playbackUrl: string | null;
    title: string;
    start: number;
    events: PlaybackEvents;
  } = $props();

  let player: HTMLVideoElement;
  let lastSaved = 0;
  let ready = false;
  let failed = $state(false);
  let startupTimer: ReturnType<typeof setTimeout> | undefined;
  const source = $derived(playbackUrl ?? convertFileSrc(path));

  function report(force = false) {
    if (!ready || failed) return;
    const { currentTime, duration, ended } = player;
    events.onTime(currentTime);
    if (force || Math.abs(currentTime - lastSaved) >= 2) {
      lastSaved = currentTime;
      events.onSave(currentTime, duration, ended);
    }
  }

  onMount(() => {
    events.onControls({
      play: () => {
        void player.play().catch(() => {});
      },
      pause: () => player.pause(),
      seek: (seconds) => {
        player.currentTime = seconds;
      },
    });
    return () => {
      clearTimeout(startupTimer);
      if (player && player.currentTime !== lastSaved) report(true);
      events.onControls(undefined);
    };
  });
</script>

<!-- The shared subtitle overlay renders optional, interactive caption tracks. -->
<!-- svelte-ignore a11y_media_has_caption -->
<video
  bind:this={player}
  class="block aspect-video min-h-[200px] w-full rounded-xl bg-black"
  aria-label={title}
  src={source}
  controls
  preload="metadata"
  onloadstart={() => {
    clearTimeout(startupTimer);
    startupTimer = setTimeout(() => (failed = true), 12_000);
  }}
  onloadedmetadata={() => {
    clearTimeout(startupTimer);
    failed = false;
    if (start > 0 && start < player.duration) player.currentTime = start;
    lastSaved = player.currentTime;
    ready = true;
    events.onTime(player.currentTime);
  }}
  ontimeupdate={() => report()}
  onseeked={() => report(true)}
  onpause={() => report(true)}
  onended={() => report(true)}
  onerror={() => {
    clearTimeout(startupTimer);
    failed = true;
  }}
></video>
{#if failed}
  <p class="mt-2 text-sm text-destructive" role="alert">
    The desktop player could not play this file.
  </p>
{/if}
