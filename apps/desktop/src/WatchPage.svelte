<script lang="ts">
  import { Maximize, Pause, Play } from "@lucide/svelte";
  import { onDestroy, onMount } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import { readVideo, saveVideoProgress } from "$lib/library/commands";
  import { exposeVideo, probeVideo, type ProbeResult, type VideoSource } from "$lib/video/commands";

  let { videoId, onBack }: { videoId: number; onBack: () => void } = $props();

  let source = $state<VideoSource | null>(null);
  let probe = $state<ProbeResult | null>(null);
  let error = $state("");
  let playing = $state(false);
  let seconds = $state(0);
  let duration = $state(0);
  let video = $state<HTMLVideoElement>();
  let stage = $state<HTMLDivElement>();
  let lastSaved = 0;

  function formatTime(value: number) {
    if (!Number.isFinite(value)) return "0:00";
    const total = Math.floor(value);
    return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
  }

  async function save(position: number) {
    if (!duration || position < 0) return;
    lastSaved = position;
    const saved = await saveVideoProgress(videoId, position, duration);
    if (!saved.ok) error = saved.error;
  }

  function onTime() {
    if (!video) return;
    seconds = video.currentTime;
    if (video.currentTime - lastSaved >= 5) void save(video.currentTime);
  }

  function togglePlay() {
    if (!video) return;
    if (video.paused) void video.play();
    else video.pause();
  }

  function seek(delta: number) {
    if (!video) return;
    video.currentTime = Math.max(0, Math.min(video.duration || 0, video.currentTime + delta));
  }

  function toggleFullscreen() {
    if (!stage) return;
    if (document.fullscreenElement) void document.exitFullscreen();
    else void stage.requestFullscreen();
  }

  function onKeydown(event: KeyboardEvent) {
    if (event.key === " " || event.code === "Space") {
      event.preventDefault();
      togglePlay();
    } else if (event.key === "ArrowLeft") {
      event.preventDefault();
      seek(-5);
    } else if (event.key === "ArrowRight") {
      event.preventDefault();
      seek(5);
    } else if (event.key.toLowerCase() === "f" || event.key === "Escape") {
      toggleFullscreen();
    }
  }

  onMount(() => {
    void (async () => {
      const saved = await readVideo(videoId);
      if (!saved.ok || !saved.data) {
        error = saved.error || "Video not found.";
        return;
      }
      const opened = await exposeVideo(saved.data.path);
      if (!opened.ok || !opened.data) {
        error = opened.error || "Could not open this video.";
        return;
      }
      source = opened.data;
      lastSaved = saved.data.seconds;
      const info = await probeVideo(opened.data.id);
      if (info.ok) probe = info.data;
      if (info.ok && info.data?.error) error = info.data.error;
    })();
  });

  onDestroy(() => {
    if (video && duration) void save(video.currentTime);
  });
</script>

<svelte:window onkeydown={onKeydown} />

<div class="flex flex-col gap-3">
  <Button variant="ghost" onclick={onBack} class="self-start">← Back to library</Button>

  {#if error}
    <p class="text-sm text-destructive" role="alert" data-testid="watch-error">{error}</p>
  {/if}

  <div bind:this={stage} class="rounded-lg border border-border bg-black" data-testid="watch-stage">
    <video
      bind:this={video}
      class="w-full"
      playsinline
      preload="metadata"
      src={source?.url ?? undefined}
      onloadedmetadata={() => {
        if (video) {
          duration = video.duration;
          video.currentTime = lastSaved;
        }
      }}
      ontimeupdate={onTime}
      onplay={() => (playing = true)}
      onpause={() => {
        playing = false;
        if (video) void save(video.currentTime);
      }}
      data-testid="video"
    >
      <track kind="captions" />
    </video>
    <div class="flex items-center gap-3 p-3 text-sm">
      <button
        type="button"
        class="rounded-md border border-border px-2 py-1"
        aria-label={playing ? "Pause" : "Play"}
        onclick={togglePlay}
      >
        {#if playing}<Pause size={16} />{:else}<Play size={16} />{/if}
      </button>
      <input
        type="range"
        min="0"
        max={duration || 0}
        step="0.1"
        value={seconds}
        aria-label="Playback position"
        class="flex-1"
        oninput={(event) => {
          if (video) video.currentTime = Number(event.currentTarget.value);
        }}
      />
      <span class="tabular-nums" data-testid="watch-clock">
        {formatTime(seconds)} / {formatTime(duration)}
      </span>
      <button
        type="button"
        class="rounded-md border border-border p-1"
        aria-label="Fullscreen"
        onclick={toggleFullscreen}
      >
        <Maximize size={16} />
      </button>
    </div>
  </div>

  <p class="text-xs text-muted-foreground" data-testid="watch-codecs">
    {probe?.container ?? ""}
    {probe?.video ?? ""}
    {(probe?.audio ?? []).join(", ")}
  </p>
</div>
