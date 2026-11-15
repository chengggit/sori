<script lang="ts">
  import { onMount, type Snippet } from "svelte";
  import { getCurrentWindow } from "@tauri-apps/api/window";
  import type { VideoController } from "@get-air/video";
  import { Maximize, Minimize, Pause, Play } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { formatPlaybackTime } from "../dashboard/playback";
  import type { PlaybackEvents } from "./playback";

  let {
    path,
    title,
    start,
    events,
    captions,
    subtitleMenu,
    fullscreen = $bindable(false),
    dismissLookup,
    captionsVisible = $bindable(true),
  }: {
    path: string;
    title: string;
    start: number;
    events: PlaybackEvents;
    captions: Snippet<[HTMLElement | undefined]>;
    subtitleMenu: Snippet;
    fullscreen?: boolean;
    dismissLookup: () => boolean;
    captionsVisible?: boolean;
  } = $props();

  let element: HTMLVideoElement;
  let overlay: HTMLDivElement;
  let playerRoot = $state<HTMLDivElement>();
  let player = $state.raw<VideoController>();
  let seconds = $state(0);
  let duration = $state(0);
  let playing = $state(false);
  let scrubPosition = $state<number | null>(null);
  let error = $state("");
  let fullscreenBusy = $state(false);
  let controlsVisible = $state(true);
  let subtitlesOpen = $state(false);
  let subtitleSettings: HTMLDivElement;
  let subtitleButton = $state<HTMLButtonElement | null>(null);
  const timelinePosition = $derived(scrubPosition ?? seconds);
  let hideTimer: ReturnType<typeof setTimeout> | undefined;
  let mounted = false;
  let ownsWindowFullscreen = false;
  let lastSaved = 0;

  function showControls() {
    controlsVisible = true;
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => (controlsVisible = false), 2300);
  }

  function dismissOutside(event: PointerEvent) {
    if (subtitlesOpen && event.target instanceof Node && !subtitleSettings.contains(event.target)) {
      subtitlesOpen = false;
    }
  }

  async function toggleFullscreen() {
    if (fullscreenBusy) return;
    fullscreenBusy = true;
    const window = getCurrentWindow();
    try {
      if (fullscreen) {
        if (ownsWindowFullscreen) await window.setFullscreen(false);
        ownsWindowFullscreen = false;
        fullscreen = false;
      } else {
        if (!(await window.isFullscreen())) {
          await window.setFullscreen(true);
          if (!mounted) {
            await window.setFullscreen(false);
            return;
          }
          ownsWindowFullscreen = true;
        }
        if (mounted) fullscreen = true;
      }
      if (mounted) showControls();
    } catch (cause) {
      if (mounted) reportError(cause);
    } finally {
      fullscreenBusy = false;
    }
  }

  function save() {
    lastSaved = seconds;
    events.onSave(seconds, duration || undefined);
  }

  function reportError(cause: unknown) {
    error = cause instanceof Error ? cause.message : String(cause);
  }

  function play() {
    if (!player) return;
    if (fullscreen) dismissLookup();
    void player.play().catch(reportError);
  }

  function pause() {
    player?.pause();
  }

  function seek(position: number) {
    if (!player || !duration) return;
    void player.seek(Math.max(0, Math.min(position, duration))).catch(reportError);
  }

  function handlePlayerKey(event: KeyboardEvent) {
    if (event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey)
      return;
    if (event.key === "Escape" && subtitlesOpen) {
      event.preventDefault();
      subtitlesOpen = false;
      subtitleButton?.focus();
      return;
    }
    if (event.key === "Escape" && fullscreen) {
      event.preventDefault();
      if (!dismissLookup()) void toggleFullscreen();
      return;
    }
    const key = event.key.toLowerCase();
    const arrow = key === "arrowleft" || key === "arrowright";
    if (!player || event.isComposing || document.querySelector('[role="dialog"][data-state="open"]')) return;
    if (!arrow && (event.repeat || ![" ", "c", "f"].includes(key))) return;
    if (
      event.target instanceof HTMLElement &&
      (event.target.closest('textarea, select, [contenteditable], [role="dialog"]') ||
        (event.target.closest("input") && !event.target.matches("[data-mpv-position]")) ||
        (key === " " && event.target.closest('button, a, [role="button"]')))
    ) return;
    event.preventDefault();
    showControls();
    if (arrow) seek(seconds + (key === "arrowright" ? 5 : -5));
    else if (key === " ") playing ? pause() : play();
    else if (key === "f") void toggleFullscreen();
    else {
      if (captionsVisible) dismissLookup();
      captionsVisible = !captionsVisible;
    }
  }

  onMount(() => {
    mounted = true;
    let attached: VideoController | undefined;
    let disposed = false;
    let initializing = false;
    let disablingNativeCaption = false;
    let unsubscribe: (() => void) | undefined;
    let unsubscribeError: (() => void) | undefined;
    let unsubscribeScale: (() => void) | undefined;
    void (async () => {
      const { createTauriVideoClient } = await import("@get-air/video-tauri");
      const window = getCurrentWindow();
      const stopScale = await window.onScaleChanged(({ payload }) => {
        element.dataset.gtkScale = String(payload.scaleFactor);
      });
      if (disposed) {
        stopScale();
        return;
      }
      unsubscribeScale = stopScale;
      const scale = await window.scaleFactor();
      if (disposed) return;
      element.dataset.gtkScale = String(scale);
      attached = await createTauriVideoClient().attach(element, {
        source: path,
        backend: "tauri",
        backendOptions: { tauri: { engine: "mpv" } },
        controlRegions: overlay,
      });
      if (disposed) {
        await attached.destroy();
        return;
      }
      const controller = attached;
      async function initialize() {
        initializing = true;
        await controller.selectTrack("subtitle");
        if (disposed) return;
        if (start > 0 && start < duration) await controller.seek(start);
        if (disposed) return;
        player = controller;
        events.onTime(seconds);
        events.onControls({ play, pause, seek });
        play();
      }
      unsubscribe = controller.on("timeupdate", ({ detail }) => {
        seconds = detail.currentTime;
        duration = controller.media.durationSeconds ?? duration;
        if (!player) {
          if (duration > 0 && !initializing) {
            void initialize().catch((cause) => {
              if (!disposed) reportError(cause);
            });
          }
          return;
        }
        events.onTime(seconds);
        if (Math.abs(seconds - lastSaved) >= 2) save();
        if (!disablingNativeCaption && controller.tracks.some((track) => track.kind === "subtitle" && track.selected)) {
          disablingNativeCaption = true;
          void controller.selectTrack("subtitle").then(() => {
            disablingNativeCaption = false;
          }, reportError);
        }
      });
      unsubscribeError = controller.on("error", ({ detail }) => reportError(detail.message));
    })().catch((cause) => {
      if (!disposed) reportError(cause);
    });
    return () => {
      mounted = false;
      clearTimeout(hideTimer);
      if (ownsWindowFullscreen) void getCurrentWindow().setFullscreen(false).catch(() => {});
      disposed = true;
      unsubscribe?.();
      unsubscribeError?.();
      unsubscribeScale?.();
      if (player && lastSaved !== seconds) save();
      void attached?.destroy().catch(() => {});
      events.onControls(undefined);
    };
  });
</script>

<svelte:window onkeydown={handlePlayerKey} onpointerdown={dismissOutside} />

<!-- Keep the 50dvh height limit and the 16:9 aspect ratio together. -->
<div class={fullscreen ? "fullscreen-stage fixed inset-0 z-50 grid place-items-center bg-black" : "contents"}>
<div
  class={["relative mx-auto w-full", fullscreen ? "max-w-[calc(100dvh*16/9)]" : "max-w-[calc(50dvh*16/9)]"]}
  role="region"
  aria-label="Video player"
  bind:this={playerRoot}
  onpointermove={showControls}
  onpointerdown={showControls}
>
  <!-- svelte-ignore a11y_media_has_caption -->
  <video
    bind:this={element}
    class={["block aspect-video w-full bg-black", !fullscreen && "rounded-xl"]}
    aria-label={title}
    onplaying={() => {
      playing = true;
      showControls();
    }}
    onpause={() => {
      playing = false;
      if (player && lastSaved !== seconds) save();
    }}
    onended={() => {
      playing = false;
      lastSaved = seconds;
      events.onSave(seconds, duration, true);
    }}
  ></video>
  <div class="pointer-events-none absolute inset-2 flex flex-col justify-end gap-2" bind:this={overlay}>
    <div class="modal-video-shade absolute -inset-2 rounded-xl"></div>
    {#if error}
      <p class="absolute inset-x-2 top-1/2 -translate-y-1/2 rounded-md bg-black/80 px-3 py-2 text-center text-sm text-white" role="alert">{error}</p>
    {/if}
    {@render captions(playerRoot)}
    <div
      class="controls pointer-events-auto rounded-lg bg-black/70 px-3 py-1 text-white transition-opacity duration-200 motion-reduce:transition-none"
      data-hidden={playing && !controlsVisible && scrubPosition === null && !subtitlesOpen}
      class:invisible={!player}
    >
      <input
        type="range"
        class="timeline block h-5 w-full"
        aria-label="Playback position"
        aria-valuetext={formatPlaybackTime(timelinePosition)}
        style:--played={`${duration ? (timelinePosition / duration) * 100 : 0}%`}
        data-mpv-position
        min="0"
        max={duration}
        step="0.1"
        value={timelinePosition}
        disabled={!player}
        oninput={(event) => (scrubPosition = event.currentTarget.valueAsNumber)}
        onchange={(event) => {
          const position = event.currentTarget.valueAsNumber;
          scrubPosition = null;
          seek(position);
          showControls();
        }}
        onblur={() => (scrubPosition = null)}
      />
      <div class="relative flex items-center gap-2">
        <Button
          size="icon-sm"
          variant="ghost"
          class="text-white hover:bg-white/20 hover:text-white"
          aria-label={playing ? "Pause" : "Play"}
          title={playing ? "Pause" : "Play"}
          disabled={!player}
          onclick={() => (playing ? pause() : play())}
        >
          {#if playing}<Pause />{:else}<Play />{/if}
        </Button>
        <span class="text-xs tabular-nums">
          {formatPlaybackTime(timelinePosition)} / {formatPlaybackTime(duration)}
        </span>
        <div class="ml-auto" bind:this={subtitleSettings}>
          <Button
            bind:ref={subtitleButton}
            size="sm"
            variant="ghost"
            class="font-semibold text-white hover:bg-white/20 hover:text-white aria-expanded:bg-white/20"
            aria-label="Subtitle settings"
            aria-expanded={subtitlesOpen}
            title="Subtitle settings"
            onclick={() => {
              subtitlesOpen = !subtitlesOpen;
              showControls();
            }}
          >
            CC
          </Button>
          {#if subtitlesOpen}
            <div
              class="absolute right-0 bottom-full mb-6 grid max-h-[35dvh] w-full max-w-72 gap-3 overflow-y-auto rounded-lg border bg-popover p-3 text-popover-foreground shadow-lg"
              role="group"
              aria-label="Subtitle tracks"
            >
              {@render subtitleMenu()}
            </div>
          {/if}
        </div>
        <Button
          size="icon-sm"
          variant="ghost"
          class="text-white hover:bg-white/20 hover:text-white"
          aria-label={fullscreen ? "Exit fullscreen" : "Fullscreen"}
          title={fullscreen ? "Exit fullscreen (Esc)" : "Fullscreen"}
          disabled={!player || fullscreenBusy}
          onclick={toggleFullscreen}
        >
          {#if fullscreen}<Minimize />{:else}<Maximize />{/if}
        </Button>
      </div>
    </div>
  </div>
</div>
</div>

<style>
  :global(body:has([data-slot="sheet-overlay"][data-state="open"])) .modal-video-shade {
    background: rgb(0 0 0 / 35%);
  }

  :global(html:has(.fullscreen-stage)) {
    overflow: hidden;
  }

  .controls[data-hidden="true"]:not(:has(:focus-visible)) {
    opacity: 0;
    pointer-events: none;
  }

  .timeline {
    appearance: none;
    background: transparent;
  }

  .timeline::-webkit-slider-runnable-track {
    height: 4px;
    border-radius: 999px;
    background: linear-gradient(to right, white var(--played), rgb(255 255 255 / 45%) var(--played));
  }

  .timeline::-webkit-slider-thumb {
    appearance: none;
    width: 14px;
    height: 14px;
    margin-top: -5px;
    border-radius: 50%;
    background: white;
  }
</style>
