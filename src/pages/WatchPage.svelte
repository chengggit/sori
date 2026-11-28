<script lang="ts">
  import {
    ArrowLeft,
    Maximize,
    Minimize,
    Pause,
    Play,
    Volume2,
    VolumeX,
    Plus,
    MoreVertical,
  } from "@lucide/svelte";
  import { Popover } from "bits-ui";
  import { onMount, onDestroy, untrack } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import AnalysisSidebar from "$lib/analysis/AnalysisSidebar.svelte";
  import CaptionDefinition from "$lib/video/CaptionDefinition.svelte";
  import TimedTranscript from "$lib/video/TimedTranscript.svelte";
  import TextTranscript from "$lib/video/TextTranscript.svelte";
  import YouTubePlayer from "$lib/video/YouTubePlayer.svelte";
  import TokenPassage from "$lib/reader/TokenPassage.svelte";
  import { WatchSession } from "$lib/video/session.svelte";
  import { formatTime } from "$lib/video/time";
  import { activeSubtitleCues } from "$lib/video/subtitles";
  import type { Analysis } from "$lib/reader/analysis";
  import type { TokenBlock } from "$lib/reader/tokens";
  import type { PlaybackControls } from "$lib/video/playback";

  let {
    videoId = 0,
    youtubeId = "",
    onBack,
  }: { videoId?: number; youtubeId?: string; onBack: () => void } = $props();
  const session = new WatchSession(
    untrack(() => videoId),
    untrack(() => youtubeId),
  );
  let video = $state<HTMLVideoElement>();
  let stage = $state<HTMLDivElement>();
  let playing = $state(false),
    seconds = $state(0),
    duration = $state(0),
    fullscreen = $state(false);
  let ready = $state(false),
    volume = $state(1),
    muted = $state(false);
  let awake = $state(true),
    menuOpen = $state(false),
    optionsOpen = $state(false),
    captionsVisible = $state(true);
  let selected = $state<Analysis | null>(null),
    compact = $state(false);
  let captionHeight = $state(0);
  let resumeAfterLookup = false,
    lastSaved = 0,
    alive = true;
  let controls: PlaybackControls | undefined;
  let hideTimer: ReturnType<typeof setTimeout>;
  const showControls = $derived(awake || !playing || menuOpen || !!selected);
  const activePrimary = $derived(
    captionsVisible && session.primary !== "off"
      ? activeSubtitleCues(session.primaryCues, seconds)
      : [],
  );
  const activeSecondary = $derived(
    captionsVisible && session.secondary !== "off"
      ? activeSubtitleCues(session.secondaryCues, seconds)
      : [],
  );
  const lookupSource = $derived(session.wordSource);
  function wake() {
    awake = true;
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => (awake = false), 2500);
  }
  function play() {
    if (youtubeId) controls?.play();
    else if (video)
      void video.play().catch((error) => {
        if (alive) session.error = `Could not play this video. ${String(error)}`;
      });
  }
  function pause() {
    if (youtubeId) controls?.pause();
    else video?.pause();
  }
  function togglePlay() {
    if (playing) pause();
    else play();
    wake();
  }
  function checkpoint() {
    if (video && ready) seconds = video.currentTime;
    if (ready) {
      lastSaved = seconds;
      void session.save(seconds, duration);
    }
  }
  function onTime(value = video?.currentTime ?? 0, length = video?.duration ?? duration) {
    seconds = value;
    if (Number.isFinite(length)) duration = length;
    if (Math.abs(seconds - lastSaved) >= 5) checkpoint();
  }
  function seekTo(value: number) {
    const next = Math.max(0, Math.min(duration || Number.MAX_SAFE_INTEGER, value));
    closeLookup(false);
    seconds = next;
    if (youtubeId) controls?.seek(next);
    else if (video && ready) video.currentTime = next;
    checkpoint();
    wake();
  }
  async function toggleFullscreen() {
    closeLookup(false);
    menuOpen = false;
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await stage?.requestFullscreen();
    } catch (error) {
      session.error = `Could not enter fullscreen. ${String(error)}`;
    }
    wake();
  }
  function closeLookup(resume = true) {
    selected = null;
    compact = false;
    if (resume && resumeAfterLookup) play();
    resumeAfterLookup = false;
  }
  function analyze(block: TokenBlock, context: string, caption = false) {
    if (!selected) resumeAfterLookup = playing;
    pause();
    selected = { word: block.text, context, tokens: block.morphemes };
    compact = caption;
  }
  function onKey(event: KeyboardEvent) {
    if (
      event.defaultPrevented ||
      (event.target instanceof HTMLElement && event.target.closest("[data-testid=analysis-panel]"))
    )
      return;
    if (event.key === "Escape") {
      if (menuOpen) {
        menuOpen = false;
        event.preventDefault();
        return;
      }
      if (selected) {
        closeLookup();
        event.preventDefault();
        return;
      }
      if (fullscreen) {
        event.preventDefault();
        void toggleFullscreen();
      }
      return;
    }
    if (
      event.ctrlKey ||
      event.metaKey ||
      event.altKey ||
      event.isComposing ||
      (event.target instanceof HTMLElement &&
        event.target.closest(
          "input,textarea,select,button,[role=button],[data-testid=analysis-panel],[data-testid=caption-definition]",
        ))
    )
      return;
    if (event.code === "Space") {
      event.preventDefault();
      togglePlay();
    } else if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      event.preventDefault();
      seekTo(seconds + (event.key === "ArrowLeft" ? -5 : 5));
    } else if (event.key.toLowerCase() === "f") {
      event.preventDefault();
      void toggleFullscreen();
    } else if (event.key.toLowerCase() === "c") {
      captionsVisible = !captionsVisible;
      closeLookup();
      wake();
    }
  }
  function audio() {
    if (video) {
      video.volume = volume;
      video.muted = muted;
    }
    wake();
  }
  onMount(() => {
    void session.load();
    window.addEventListener("pagehide", checkpoint);
  });
  onDestroy(() => {
    checkpoint();
    alive = false;
    session.destroy();
    clearTimeout(hideTimer);
    window.removeEventListener("pagehide", checkpoint);
  });
</script>

<svelte:window
  onkeydown={onKey}
  onfullscreenchange={() => {
    fullscreen = document.fullscreenElement === stage;
    closeLookup(false);
    wake();
  }}
/>
<div class="watch-workspace" class:analysis-open={!!selected && !compact}>
  <div class="watch-column">
    <Button variant="ghost" class="back" onclick={onBack}><ArrowLeft size={16} /> Back</Button>
    {#if session.error}<p class="text-sm text-destructive" role="alert" data-testid="watch-error">
        {session.error}
      </p>{/if}
    <div
      bind:this={stage}
      class="stage"
      data-testid="watch-stage"
      onpointermove={wake}
      onfocusin={wake}
      ondblclick={(event) => {
        if (
          !(event.target as HTMLElement).closest(
            "button,input,[data-testid=caption-definition],[data-testid=analysis-panel]",
          )
        )
          void toggleFullscreen();
      }}
      role="region"
      aria-label="Video player"
    >
      {#if youtubeId && !session.loading}
        <YouTubePlayer
          id={youtubeId}
          title={session.title}
          start={session.start}
          events={{
            onTime: (time, total) => onTime(time, total),
            onState: (value) => (playing = value),
            onError: (message) => (session.error = message),
            onSave: (time, total) => void session.save(time, total ?? duration),
            onControls: (next) => {
              controls = next;
              ready = !!next;
            },
          }}
        />
      {:else if !youtubeId}
        <video
          bind:this={video}
          data-testid="video"
          playsinline
          preload="metadata"
          src={session.source?.url}
          onloadedmetadata={() => {
            if (video) {
              duration = Number.isFinite(video.duration) ? video.duration : 0;
              video.currentTime = Math.min(session.start, duration);
              seconds = video.currentTime;
              lastSaved = seconds;
              ready = true;
              audio();
            }
          }}
          ontimeupdate={() => onTime()}
          onplay={() => {
            playing = true;
            session.error = "";
            wake();
          }}
          onpause={() => {
            playing = false;
            checkpoint();
          }}
          onended={() => {
            playing = false;
            checkpoint();
          }}
          onerror={() => {
            if (session.source)
              session.error =
                "This video could not be played. Its codecs may not be supported by this player.";
          }}
          onclick={() => {
            if (selected) closeLookup();
            else togglePlay();
          }}
        >
          <track kind="captions" />
        </video>
      {/if}
      {#if !session.source && !youtubeId}<p class="stage-message">
          {session.error || (session.loading ? "Opening video…" : "Video unavailable.")}
        </p>{/if}
      <div
        class="captions"
        class:raised={showControls && !youtubeId}
        bind:clientHeight={captionHeight}
        data-testid="subtitle-overlay"
      >
        {#each activePrimary as cue, index (`${cue.start}-${index}`)}<div
            class="caption primary"
            data-testid="primary-caption"
            lang="ko"
          >
            <TokenPassage
              text={cue.text}
              start={0}
              root={stage}
              selectedStart={undefined}
              onToken={(block) => analyze(block, cue.text, true)}
            />
          </div>{/each}
        {#each activeSecondary as cue, index (`${cue.start}-${index}`)}<div
            class="caption secondary"
            data-testid="secondary-caption"
          >
            {cue.text}
          </div>{/each}
      </div>
      {#if selected && compact}<div
          class="caption-popup"
          style:bottom={`${captionHeight + (showControls ? 92 : 32) + 12}px`}
        >
          <CaptionDefinition
            analysis={selected}
            source={lookupSource}
            onClose={() => closeLookup()}
            onExpand={() => (compact = false)}
          />
        </div>{/if}
      {#if !youtubeId}<div class="controls" class:visible={showControls} inert={!showControls}>
          <input
            class="timeline"
            type="range"
            min="0"
            max={duration || 1}
            step="0.1"
            value={seconds}
            aria-label="Playback position"
            disabled={!ready}
            oninput={(event) => seekTo(Number(event.currentTarget.value))}
          />
          <div class="control-row">
            <button
              class="player-button"
              aria-label={playing ? "Pause" : "Play"}
              disabled={!ready}
              onclick={togglePlay}
            >
              {#if playing}<Pause size={15} />{:else}<Play size={15} />{/if}
            </button>
            <span class="clock" data-testid="watch-clock">
              {formatTime(seconds)} / {formatTime(duration)}
            </span>
            <button
              class="player-button ml-auto"
              aria-label={muted ? "Unmute" : "Mute"}
              onclick={() => {
                muted = !muted;
                audio();
              }}
            >
              {#if muted}<VolumeX size={15} />{:else}<Volume2 size={15} />{/if}
            </button>
            <input
              class="volume"
              type="range"
              min="0"
              max="1"
              step="0.01"
              value={muted ? 0 : volume}
              aria-label="Volume"
              oninput={(event) => {
                volume = Number(event.currentTarget.value);
                muted = volume === 0;
                audio();
              }}
            />
            <Popover.Root bind:open={menuOpen}>
              <Popover.Trigger class="player-button cc" aria-label="Subtitle and audio settings">
                CC
              </Popover.Trigger><Popover.Content
                side="top"
                align="end"
                sideOffset={12}
                class="track-menu"
                data-testid="track-menu"
              >
                <label>
                  Primary subtitle<select
                    aria-label="Primary subtitle track"
                    value={session.primary}
                    onchange={(event) => void session.selectTrack("primary", event.currentTarget.value)}
                  >
                    {#each session.options as option (option.value)}<option value={option.value}>
                        {option.label}
                      </option>{/each}
                  </select>
                </label>
                <label>
                  Secondary subtitle<select
                    aria-label="Secondary subtitle track"
                    value={session.secondary}
                    onchange={(event) =>
                      void session.selectTrack("secondary", event.currentTarget.value)}
                  >
                    {#each session.options as option (option.value)}<option value={option.value}>
                        {option.label}
                      </option>{/each}
                  </select>
                </label>
                <label class="check">
                  <input type="checkbox" bind:checked={captionsVisible} /> Show subtitles
                </label>
                <Button
                  variant="outline"
                  size="sm"
                  class="w-full"
                  disabled={session.importing}
                  onclick={() => void session.attachSubtitles()}
                  data-testid="attach-subtitles"
                >
                  Add subtitle files
                </Button>
                {#if session.trackLoading}<p role="status">Loading subtitles…</p>{/if}
                {#if session.trackError}<p role="alert" class="text-destructive">
                    {session.trackError}
                  </p>{/if}
              </Popover.Content>
            </Popover.Root>
            <button
              class="player-button"
              aria-label={fullscreen ? "Exit fullscreen" : "Fullscreen"}
              onclick={() => void toggleFullscreen()}
            >
              {#if fullscreen}<Minimize size={15} />{:else}<Maximize size={15} />{/if}
            </button>
          </div>
        </div>{/if}
      {#if selected && !compact && fullscreen}<AnalysisSidebar
          analysis={selected}
          source={lookupSource}
          fullHeight
          onClose={() => closeLookup()}
          testId="watch-analysis"
        />{/if}
    </div>
    <h1 class="video-title" data-testid="watch-title">{session.title || "Video"}</h1>
    <section class="transcript-card" aria-label="Transcript">
      <header class="transcript-header">
        <h2>Transcript</h2>
        <div class="ml-auto flex items-center gap-2">
          {#if youtubeId}<Button
              variant="ghost"
              size="sm"
              onclick={() => void session.fetchCaptions()}
              disabled={session.trackLoading}
              data-testid="fetch-transcript"
            >
              {session.trackLoading ? "Fetching…" : "Fetch captions"}
            </Button>{/if}
          {#if session.text.content}
            <Button
              variant="ghost"
              size="sm"
              onclick={() => (session.showingText = !session.showingText)}
            >
              {session.showingText ? "Show subtitles" : "Show text"}
            </Button>
            <Popover.Root bind:open={optionsOpen}>
              <Popover.Trigger
                class="p-2 rounded-md hover:bg-neutral-hover"
                aria-label="Transcript options"
              >
                <MoreVertical size={16} />
              </Popover.Trigger><Popover.Content side="bottom" align="end" class="transcript-options">
                <button
                  onclick={() => {
                    optionsOpen = false;
                    void session.attachText();
                  }}
                >
                  Replace transcript (.txt)
                </button><button
                  onclick={() => {
                    optionsOpen = false;
                    void session.removeText();
                  }}
                >
                  Remove transcript
                </button>
              </Popover.Content>
            </Popover.Root>
          {:else}<Button
              variant="outline"
              size="sm"
              disabled={session.importing}
              onclick={() => void session.attachText()}
            >
              <Plus size={14} /> Add transcript
            </Button>{/if}
        </div>
      </header>
      {#if session.showingText && session.text.title}<p class="transcript-name">
          {session.text.title}
        </p>{/if}
      {#if session.transcriptError}<p class="px-6 pb-3 text-sm text-destructive" role="alert">
          {session.transcriptError}
        </p>{/if}
      {#if session.trackError && !menuOpen}<p class="px-6 pb-3 text-sm text-destructive" role="alert">
          {session.trackError}
        </p>{/if}
      {#if session.showingText && session.text.content}
        {#key session.text}<TextTranscript
            text={session.text}
            isCurrent={(text) => text === session.text}
            source={lookupSource}
            onAnalyze={analyze}
            onError={(message) => (session.transcriptError = message)}
          />{/key}
      {:else if session.primaryCues.length && session.primary !== "off"}<TimedTranscript
          cues={session.primaryCues}
          {seconds}
          onSeek={seekTo}
          onAnalyze={analyze}
        />
      {:else}<div class="empty-transcript">
          <p>
            {session.loading || session.trackLoading
              ? "Loading subtitles…"
              : "Select a primary text track in CC or add an SRT or VTT file."}
          </p>
          {#if !youtubeId}<Button
              variant="outline"
              size="sm"
              onclick={() => {
                menuOpen = true;
                wake();
              }}
            >
              Subtitle settings
            </Button>{/if}
        </div>{/if}
    </section>
  </div>
</div>
{#if selected && !compact && !fullscreen}<AnalysisSidebar
    analysis={selected}
    source={lookupSource}
    fullHeight
    onClose={() => closeLookup()}
    testId="watch-analysis"
  />{/if}

<style>
  .watch-workspace {
    height: 100%;
    overflow: auto;
    padding: 24px 24px 16px;
  }
  .watch-column {
    display: flex;
    flex-direction: column;
    height: 100%;
    max-width: min(920px, calc(var(--app-height) * 0.42 * 16 / 9));
    margin: auto;
    min-height: 650px;
  }
  :global(.back) {
    align-self: flex-start;
    margin-bottom: 16px;
  }
  .stage {
    position: relative;
    flex-shrink: 0;
    width: 100%;
    aspect-ratio: 16/9;
    background: black;
    border-radius: 14px;
    overflow: hidden;
  }
  video {
    width: 100%;
    height: 100%;
    object-fit: contain;
  }
  .stage-message {
    position: absolute;
    top: 50%;
    width: 100%;
    padding: 20px;
    text-align: center;
    color: #bbb;
    transform: translateY(-50%);
  }
  .stage:fullscreen {
    width: 100%;
    height: 100%;
    border-radius: 0;
    aspect-ratio: auto;
  }
  .stage:fullscreen .caption {
    font-size: 28px;
  }
  .controls {
    position: absolute;
    bottom: 0;
    left: 8px;
    right: 8px;
    padding: 8px 12px 10px;
    background: linear-gradient(transparent, #000d);
    border-radius: 12px 12px 0 0;
    color: white;
    opacity: 0;
    transition: opacity 180ms;
    pointer-events: none;
  }
  .controls.visible {
    opacity: 1;
    pointer-events: auto;
  }
  .control-row {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .timeline {
    width: 100%;
    height: 14px;
    display: block;
    margin-bottom: 5px;
  }
  .volume {
    width: 90px;
    height: 14px;
  }
  input[type="range"] {
    accent-color: white;
    cursor: pointer;
  }
  .clock {
    font-size: 12px;
    font-variant-numeric: tabular-nums;
  }
  :global(.player-button) {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 30px;
    height: 30px;
    flex-shrink: 0;
    border-radius: 6px;
    background: transparent;
    color: white;
    border: 0;
  }
  :global(.player-button:hover) {
    background: #ffffff40;
  }
  :global(.player-button:disabled) {
    opacity: 0.5;
  }
  :global(.cc) {
    font-size: 12px;
    font-weight: 600;
  }
  .captions {
    position: absolute;
    bottom: 32px;
    left: 14px;
    right: 14px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 3px;
    pointer-events: none;
  }
  .captions.raised {
    bottom: 82px;
  }
  .caption {
    background: #000d;
    padding: 4px 12px;
    border-radius: 6px;
    color: white;
    text-align: center;
    white-space: pre-wrap;
    line-height: 1.4;
    max-width: 100%;
    pointer-events: auto;
  }
  .primary {
    font-family: var(--font-korean);
    font-size: 21px;
  }
  .caption :global([role="button"]:hover) {
    color: #fde68a;
  }
  .secondary {
    font-size: 16px;
  }
  .caption-popup {
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
    z-index: 3;
  }
  .video-title {
    font-size: 20px;
    font-weight: 600;
    margin: 16px 0 20px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex-shrink: 0;
  }
  .transcript-card {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-height: 200px;
    border: 1px solid var(--border);
    background: var(--card);
    border-radius: 12px;
    overflow: hidden;
  }
  .transcript-header {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px 24px 12px;
    flex-wrap: wrap;
  }
  .transcript-header h2 {
    font-size: 14px;
    font-weight: 600;
  }
  .transcript-name {
    font-size: 12px;
    color: var(--muted-foreground);
    padding: 0 24px 10px;
  }
  .empty-transcript {
    padding: 12px 24px;
    display: grid;
    justify-items: start;
    gap: 12px;
    color: var(--muted-foreground);
    font-size: 14px;
  }
  :global(.track-menu) {
    width: 300px;
    max-width: calc(100vw - 32px);
    padding: 14px;
    background: var(--card);
    color: var(--foreground);
    border: 1px solid var(--border);
    border-radius: 12px;
    z-index: 35;
    box-shadow: 0 6px 25px #0002;
    display: grid;
    gap: 12px;
    font-size: 13px;
  }
  :global(.track-menu label:not(.check)) {
    display: grid;
    gap: 8px;
    color: var(--muted-foreground);
    font-size: 12px;
  }
  :global(.track-menu select) {
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 8px;
    color: var(--foreground);
    background: var(--background);
    width: 100%;
    font-size: 13px;
  }
  :global(.track-menu .check) {
    display: flex;
    gap: 8px;
    align-items: center;
  }
  :global(.transcript-options) {
    z-index: 35;
    display: grid;
    padding: 4px;
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 8px;
    box-shadow: 0 6px 25px #0002;
  }
  :global(.transcript-options button) {
    text-align: left;
    padding: 8px 12px;
    border-radius: 4px;
    font-size: 13px;
  }
  :global(.transcript-options button:hover) {
    background: var(--neutral-hover);
  }
  @media (min-width: 1100px) {
    .watch-workspace.analysis-open {
      padding-right: 524px;
    }
  }
  @media (max-width: 600px) {
    .watch-workspace {
      padding: 16px 12px;
    }
    .volume {
      width: 60px;
    }
    .control-row {
      gap: 4px;
    }
    .watch-column {
      min-height: 550px;
    }
    .video-title {
      font-size: 17px;
    }
    .transcript-header {
      padding-inline: 16px;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .controls {
      transition: none;
    }
  }
</style>
