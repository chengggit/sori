<script lang="ts">
  import { Maximize, Pause, Play } from "@lucide/svelte";
  import { onDestroy, onMount } from "svelte";
  import AnalysisPanel from "$lib/reader/AnalysisPanel.svelte";
  import { Button } from "$lib/components/ui/button";
  import { tokenBlocks } from "$lib/reader/tokens";
  import { tokenizeText, type KoreanToken } from "$lib/nlp/tokenization";
  import { ui } from "$lib/ui-state.svelte";
  import { activeSubtitleCues, parseSubtitles, type SubtitleCue } from "$lib/video/subtitles";
  import { readVideo, saveVideoProgress } from "$lib/library/commands";
  import {
    attachSubtitles,
    exposeVideo,
    probeVideo,
    videoTrack,
    type ProbeResult,
    type VideoSource,
  } from "$lib/video/commands";

  let { videoId, onBack }: { videoId: number; onBack: () => void } = $props();

  let source = $state<VideoSource | null>(null);
  let probe = $state<ProbeResult | null>(null);
  let error = $state("");
  let playing = $state(false);
  let seconds = $state(0);
  let duration = $state(0);
  let video = $state<HTMLVideoElement>();
  let stage = $state<HTMLDivElement>();
  let transcript = $state<HTMLElement>();
  let lastSaved = 0;

  let primary = $state("off");
  let secondary = $state("off");
  let captionsVisible = $state(true);
  let follow = $state(true);
  let primaryCues = $state<SubtitleCue[]>([]);
  let secondaryCues = $state<SubtitleCue[]>([]);
  let attachedCues = $state<SubtitleCue[]>([]);
  let cueTokens = $state<Record<string, KoreanToken[]>>({});
  let selected = $state<{ word: string; context: string; tokens: KoreanToken[] } | null>(null);

  const activePrimary = $derived(activeSubtitleCues(primaryCues, seconds));
  const activeSecondary = $derived(activeSubtitleCues(secondaryCues, seconds));
  const trackOptions = $derived([
    { value: "off", label: "Off" },
    ...(probe?.tracks ?? []).map((track) => ({
      value: `index:${track.index}`,
      label: track.label || `Track ${track.index}`,
    })),
    ...(attachedCues.length ? [{ value: "attached", label: "Attached file" }] : []),
  ]);

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

  function seekTo(value: number) {
    if (!video) return;
    video.currentTime = Math.max(0, Math.min(video.duration || 0, value));
    seconds = video.currentTime;
  }

  function seek(delta: number) {
    seekTo((video?.currentTime ?? 0) + delta);
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
    } else if (event.key.toLowerCase() === "c") {
      captionsVisible = !captionsVisible;
    }
  }

  async function rememberTokens(text: string) {
    if (cueTokens[text]) return;
    try {
      cueTokens[text] = await tokenizeText(text);
    } catch {
      cueTokens[text] = [];
    }
  }

  async function useCues(which: "primary" | "secondary", cues: SubtitleCue[]) {
    for (const cue of cues) await rememberTokens(cue.text);
    if (which === "primary") primaryCues = cues;
    else secondaryCues = cues;
  }

  async function selectTrack(which: "primary" | "secondary", value: string) {
    if (which === "primary") primary = value;
    else secondary = value;
    if (value === "off") {
      await useCues(which, []);
    } else if (value === "attached") {
      await useCues(which, attachedCues);
    } else if (source && value.startsWith("index:")) {
      const reply = await videoTrack(source.id, Number(value.slice(6)));
      if (!reply.ok || !reply.data) {
        error = reply.error || "Could not extract this subtitle track.";
        return;
      }
      await useCues(which, parseSubtitles(reply.data));
    }
  }

  async function attachFile() {
    if (!source) return;
    const reply = await attachSubtitles(source.id);
    if (!reply.ok) {
      error = reply.error;
      return;
    }
    if (!reply.data) return;
    const cues = parseSubtitles(reply.data.text);
    attachedCues = cues;
    await useCues("primary", cues);
    primary = "attached";
  }

  function analyze(block: { text: string; morphemes: KoreanToken[] }, context: string) {
    if (!block.morphemes.length) return;
    selected = { word: block.text, context, tokens: block.morphemes };
  }

  $effect(() => {
    if (!follow || !transcript || !activePrimary.length) return;
    const node = transcript.querySelector(`[data-cue="${activePrimary[0].start}"]`);
    node?.scrollIntoView({ block: "nearest" });
  });

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
      if (!info.ok) return;
      probe = info.data;
      if (info.data?.error) error = info.data.error;

      const korean = (info.data?.tracks ?? []).find((track) =>
        /ko|kor|korean/i.test(`${track.language} ${track.label}`),
      );
      const english = (info.data?.tracks ?? []).find((track) =>
        /en|eng|english/i.test(`${track.language} ${track.label}`),
      );
      if (korean) await selectTrack("primary", `index:${korean.index}`);
      if (english && english.index !== korean?.index) {
        await selectTrack("secondary", `index:${english.index}`);
      }
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

  <div class="flex flex-wrap items-center gap-2 text-sm">
    <label class="flex items-center gap-1">
      Primary
      <select
        aria-label="Primary subtitle track"
        class="rounded-md border border-input bg-transparent px-2 py-1"
        value={primary}
        onchange={(event) => void selectTrack("primary", event.currentTarget.value)}
      >
        {#each trackOptions as option (option.value)}
          <option value={option.value}>{option.label}</option>
        {/each}
      </select>
    </label>
    <label class="flex items-center gap-1">
      Secondary
      <select
        aria-label="Secondary subtitle track"
        class="rounded-md border border-input bg-transparent px-2 py-1"
        value={secondary}
        onchange={(event) => void selectTrack("secondary", event.currentTarget.value)}
      >
        {#each trackOptions as option (option.value)}
          <option value={option.value}>{option.label}</option>
        {/each}
      </select>
    </label>
    <Button variant="outline" onclick={attachFile} data-testid="attach-subtitles">
      Attach SRT/VTT
    </Button>
  </div>

  <div class="flex flex-wrap gap-4">
    <div class="min-w-0 flex-1">
      <div
        bind:this={stage}
        class="relative rounded-lg border border-border bg-black"
        data-testid="watch-stage"
      >
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

        {#if captionsVisible}
          <div
            class="pointer-events-none absolute inset-x-0 bottom-12 flex flex-col items-center gap-1"
            data-testid="subtitle-overlay"
          >
            {#each activePrimary as cue (cue.start)}
              <div
                class="pointer-events-auto rounded bg-black/70 px-2 py-1 text-center text-white"
                data-testid="primary-caption"
              >
                {#each tokenBlocks(cue.text, cueTokens[cue.text] ?? []) as block, index (index)}{#if block.morphemes.length}<button
                      type="button"
                      class="underline decoration-dotted underline-offset-4"
                      onclick={() => analyze(block, cue.text)}
                    >
                      {block.text}
                    </button>{:else}{block.text}{/if}{/each}
              </div>
            {/each}
            {#each activeSecondary as cue (cue.start)}
              <div
                class="rounded bg-black/60 px-2 py-1 text-center text-sm text-zinc-200"
                data-testid="secondary-caption"
              >
                {cue.text}
              </div>
            {/each}
          </div>
        {/if}
      </div>

      <div class="flex items-center gap-3 rounded-b-lg border border-t-0 border-border p-3 text-sm">
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
          oninput={(event) => seekTo(Number(event.currentTarget.value))}
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

      <p class="text-xs text-muted-foreground" data-testid="watch-codecs">
        {probe?.container ?? ""}
        {probe?.video ?? ""}
        {(probe?.audio ?? []).join(", ")}
      </p>
    </div>

    {#if selected}
      <aside class="w-full min-w-72 max-w-md" data-testid="watch-analysis">
        <AnalysisPanel analysis={selected} />
      </aside>
    {/if}

    {#if primaryCues.length}
      <aside class="w-full min-w-64 max-w-xs">
        <div class="mb-2 flex items-center justify-between">
          <h2 class="text-sm font-semibold">Transcript</h2>
          {#if !follow}
            <Button variant="outline" onclick={() => (follow = true)} data-testid="resume-follow">
              Resume follow
            </Button>
          {/if}
        </div>
        <div
          bind:this={transcript}
          class="h-[60vh] overflow-auto rounded-lg border border-border bg-card p-2"
          data-testid="transcript"
          onscroll={() => (follow = false)}
        >
          {#each primaryCues as cue (cue.start)}
            <button
              type="button"
              class="block w-full rounded px-2 text-left text-sm hover:bg-neutral-hover"
              style:line-height={`${ui.transcriptLineHeight}px`}
              class:bg-accent-soft={cue.start <= seconds && cue.end > seconds}
              data-cue={cue.start}
              data-testid={`cue-${cue.start}`}
              onclick={() => seekTo(cue.start)}
            >
              <span class="mr-2 text-xs text-muted-foreground">{formatTime(cue.start)}</span>
              {cue.text}
            </button>
          {/each}
        </div>
      </aside>
    {/if}
  </div>
</div>
