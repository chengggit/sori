<script lang="ts">
  import { onMount } from "svelte";
  import type { VideoController } from "@get-air/video";
  import { Button } from "$lib/components/ui/button";
  import { formatPlaybackTime } from "../dashboard/playback";
  import type { PlaybackEvents } from "./playback";

  let {
    url,
    title,
    start,
    events,
    overlay,
  }: {
    url: string;
    title: string;
    start: number;
    events: PlaybackEvents;
    overlay?: HTMLElement;
  } = $props();

  let element: HTMLVideoElement;
  let player = $state.raw<VideoController>();
  let seconds = $state(0);
  let duration = $state(0);
  let playing = $state(false);
  let error = $state("");
  let lastSaved = 0;

  $effect(() => {
    if (player && overlay) return player.registerControls(overlay);
  });

  function save() {
    lastSaved = seconds;
    events.onSave(seconds, duration || undefined);
  }

  function reportError(cause: unknown) {
    error = cause instanceof Error ? cause.message : String(cause);
  }

  function play() {
    if (!player) return;
    void player.play().then(() => {
      playing = true;
    }, reportError);
  }

  function pause() {
    player?.pause();
    playing = false;
    save();
  }

  function seek(position: number) {
    void player?.seek(position).catch(reportError);
  }

  onMount(() => {
    let attached: VideoController | undefined;
    let disposed = false;
    let unsubscribe: (() => void) | undefined;
    void (async () => {
      const { createTauriVideoClient } = await import("@get-air/video-tauri");
      if (disposed) return;
      attached = await createTauriVideoClient().attach(element, {
        source: url,
        backend: "tauri",
        backendOptions: { tauri: { engine: "mpv" } },
      });
      if (disposed) {
        await attached.destroy();
        return;
      }
      player = attached;
      duration = attached.media.durationSeconds ?? 0;
      unsubscribe = attached.on("timeupdate", ({ detail }) => {
        seconds = detail.currentTime;
        duration = attached?.media.durationSeconds ?? duration;
        events.onTime(seconds);
        if (Math.abs(seconds - lastSaved) >= 2) save();
      });
      attached.on("error", ({ detail }) => reportError(detail.message));
      events.onControls({ play, pause, seek });
      if (start > 0) await attached.seek(start);
      if (!disposed) play();
    })().catch((cause) => {
      if (!disposed) reportError(cause);
    });
    return () => {
      disposed = true;
      unsubscribe?.();
      if (player) {
        if (lastSaved !== seconds) save();
        void player.destroy().catch(() => {});
      }
      events.onControls(undefined);
    };
  });
</script>

<!-- The Watch screen displays synchronized subtitle cues above this native video surface. -->
<!-- svelte-ignore a11y_media_has_caption -->
<video
  bind:this={element}
  class="block aspect-video min-h-[200px] w-full rounded-xl bg-black"
  aria-label={title}
></video>
<div class="mt-2 flex items-center gap-3">
  <Button size="sm" variant="outline" disabled={!player} onclick={() => (playing ? pause() : play())}>
    {playing ? "Pause" : "Play"}
  </Button>
  <input
    type="range"
    class="min-w-0 flex-1"
    aria-label="Playback position"
    min="0"
    max={duration}
    step="0.1"
    value={seconds}
    disabled={!duration}
    onchange={(event) => seek(event.currentTarget.valueAsNumber)}
  />
  <span class="text-sm tabular-nums text-muted-foreground">{formatPlaybackTime(seconds)}</span>
</div>
{#if error}
  <p class="mt-2 text-sm text-destructive" role="alert">{error}</p>
{:else if !player}
  <p class="mt-2 text-sm text-muted-foreground" role="status">Opening mpv…</p>
{/if}
