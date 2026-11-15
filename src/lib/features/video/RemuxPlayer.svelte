<script lang="ts">
  import { onMount } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import { formatPlaybackTime } from "../dashboard/playback";
  import { openRemuxStream } from "./local";
  import type { PlaybackEvents } from "./playback";

  let {
    id,
    title,
    start,
    events,
  }: {
    id: number;
    title: string;
    start: number;
    events: PlaybackEvents;
  } = $props();

  let element: HTMLVideoElement;
  let url = $state("");
  let position = $state(0);
  let duration = $state(0);
  let playing = $state(false);
  let loading = $state(true);
  let error = $state("");
  let base = 0;
  let request = 0;
  let lastSaved = 0;
  let lastRequested = 0;
  let hasPlayed = false;
  let wantsPlayback = true;
  let startupTimer: ReturnType<typeof setTimeout> | undefined;

  function reportError(cause: unknown) {
    clearTimeout(startupTimer);
    loading = false;
    error = cause instanceof Error ? cause.message : String(cause);
  }

  function stopStream() {
    if (element?.hasAttribute("src")) {
      element.removeAttribute("src");
      element.load();
    }
    url = "";
  }

  function save(completed = false) {
    if (!hasPlayed) return;
    lastSaved = position;
    events.onSave(position, duration, completed);
  }

  function reportPosition() {
    if (loading || !url || !hasPlayed) return;
    position = Math.min(duration, base + element.currentTime);
    events.onTime(position);
    if (Math.abs(position - lastSaved) >= 2) save();
  }

  async function seek(seconds: number) {
    const current = ++request;
    lastRequested = duration ? Math.min(seconds, Math.max(0, duration - 0.1)) : seconds;
    loading = true;
    playing = false;
    clearTimeout(startupTimer);
    error = "";
    hasPlayed = false;
    stopStream();
    try {
      const stream = await openRemuxStream(id, lastRequested);
      if (current !== request) return;
      base = stream.start;
      duration = stream.duration;
      position = base;
      lastSaved = base;
      events.onTime(position);
      url = stream.url;
      startupTimer = setTimeout(() => {
        stopStream();
        reportError("The MP4 stream did not start. Try again or switch players.");
      }, 15_000);
    } catch (cause) {
      if (current === request) reportError(cause);
    }
  }

  function play() {
    wantsPlayback = true;
    if (!url) {
      if (!loading) void seek(lastRequested);
      return;
    }
    void element.play().catch((cause) => {
      if (cause instanceof DOMException && ["AbortError", "NotAllowedError"].includes(cause.name))
        return;
      reportError(cause);
    });
  }

  function pause() {
    wantsPlayback = false;
    element.pause();
  }

  onMount(() => {
    events.onControls({
      play,
      pause,
      seek: (seconds) => {
        void seek(seconds);
      },
    });
    void seek(start);
    return () => {
      request++;
      clearTimeout(startupTimer);
      save();
      stopStream();
      events.onControls(undefined);
    };
  });
</script>

<!-- The Watch screen renders the selected subtitles above this video. -->
<!-- svelte-ignore a11y_media_has_caption -->
<video
  bind:this={element}
  class="block aspect-video min-h-[200px] w-full rounded-xl bg-black"
  aria-label={title}
  src={url || undefined}
  preload="auto"
  oncanplay={() => {
    if (!loading || !url) return;
    clearTimeout(startupTimer);
    loading = false;
    if (wantsPlayback) play();
  }}
  onplaying={() => {
    hasPlayed = true;
    playing = true;
    reportPosition();
  }}
  onpause={() => {
    playing = false;
    if (!loading) save();
  }}
  ontimeupdate={reportPosition}
  onended={() => save(position >= duration - 1)}
  onerror={() => {
    if (url) reportError(element.error?.message || "Could not play the MP4 stream.");
  }}
></video>

<div class="mt-2 flex items-center gap-3">
  <Button size="sm" variant="outline" disabled={loading} onclick={() => (playing ? pause() : play())}>
    {playing ? "Pause" : url ? "Play" : "Retry"}
  </Button>
  <input
    type="range"
    class="min-w-0 flex-1"
    aria-label="Playback position"
    min="0"
    max={duration}
    step="0.1"
    value={position}
    disabled={!duration}
    onchange={(event) => void seek(event.currentTarget.valueAsNumber)}
  />
  <span class="text-sm tabular-nums text-muted-foreground">{formatPlaybackTime(position)}</span>
</div>
{#if error}
  <p class="mt-2 text-sm text-destructive" role="alert">{error}</p>
{:else if loading}
  <p class="mt-2 text-sm text-muted-foreground" role="status">Starting MP4 stream…</p>
{/if}
