<script lang="ts">
  import { onDestroy, tick } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import TokenPassage from "$lib/reader/TokenPassage.svelte";
  import type { TokenBlock } from "$lib/reader/tokens";
  import type { SubtitleCue } from "./subtitles";
  import { formatTime } from "./time";
  import { ui } from "$lib/ui-state.svelte";
  let {
    cues,
    seconds,
    onSeek,
    onAnalyze,
  }: {
    cues: SubtitleCue[];
    seconds: number;
    onSeek: (seconds: number) => void;
    onAnalyze: (block: TokenBlock, context: string) => void;
  } = $props();
  let root = $state<HTMLDivElement>();
  let follow = $state(true);
  let resumeTimer: ReturnType<typeof setTimeout>;
  const current = $derived(cues.findIndex((cue) => cue.start <= seconds && cue.end > seconds));
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  function pauseFollow() {
    follow = false;
    clearTimeout(resumeTimer);
    resumeTimer = setTimeout(() => (follow = true), 5000);
  }
  function resume() {
    clearTimeout(resumeTimer);
    follow = true;
  }
  $effect(() => {
    const index = current;
    if (!follow || !root || index < 0) return;
    void tick().then(() => {
      if (!follow || !root) return;
      const node = root.querySelector<HTMLElement>(`[data-row="${index}"]`);
      if (node) root.scrollTo({ top: node.offsetTop, behavior: reduced ? "instant" : "smooth" });
    });
  });
  onDestroy(() => clearTimeout(resumeTimer));
</script>

<div class="transcript-body">
  {#if !follow}<Button
      class="resume"
      variant="outline"
      size="sm"
      onclick={resume}
      data-testid="resume-follow"
    >
      Resume follow
    </Button>{/if}
  <!-- svelte-ignore a11y_no_noninteractive_tabindex, a11y_no_noninteractive_element_interactions (The scroll region needs keyboard focus for native scrolling.) -->
  <div
    bind:this={root}
    class="cues"
    data-testid="transcript"
    onwheel={pauseFollow}
    onpointerdown={pauseFollow}
    onkeydown={(event) => {
      if (["PageDown", "PageUp", "ArrowDown", "ArrowUp", "Home", "End"].includes(event.key))
        pauseFollow();
    }}
    role="region"
    aria-label="Subtitle transcript"
    tabindex="0"
  >
    {#each cues as cue, index (index)}
      <div class="cue" class:active={index === current} data-row={index} data-cue={cue.start}>
        <button
          class="timestamp"
          type="button"
          aria-label={`Seek to ${formatTime(cue.start)}`}
          data-testid={`cue-${cue.start}`}
          onclick={() => {
            resume();
            onSeek(cue.start);
          }}
        >
          {formatTime(cue.start)}
        </button>
        <div class="cue-text" lang="ko" style:line-height={`${ui.transcriptLineHeight}px`}>
          <TokenPassage
            text={cue.text}
            start={0}
            {root}
            selectedStart={undefined}
            onToken={(block) => onAnalyze(block, cue.text)}
          />
        </div>
      </div>
    {/each}
    <div class="tail" aria-hidden="true"></div>
  </div>
</div>

<style>
  .transcript-body {
    position: relative;
    flex: 1;
    min-height: 0;
  }
  .cues {
    position: relative;
    height: 100%;
    overflow: auto;
    padding: 0 24px;
  }
  .cue {
    display: flex;
    gap: 8px;
    border-radius: 8px;
    min-height: 48px;
    margin: 4px 0;
    position: relative;
  }
  .cue:hover {
    background: var(--neutral-hover);
  }
  .cue.active {
    background: var(--accent-soft);
  }
  .cue.active::before {
    content: "";
    position: absolute;
    left: 0;
    top: 10px;
    bottom: 10px;
    width: 3px;
    border-radius: 2px;
    background: var(--accent);
  }
  .timestamp {
    width: 78px;
    flex-shrink: 0;
    align-self: flex-start;
    padding: 12px 0;
    font-size: 12px;
    font-variant-numeric: tabular-nums;
    color: var(--muted-foreground);
    border-radius: 6px;
  }
  .cue-text {
    min-width: 0;
    padding: 10px 12px 10px 0;
    white-space: pre-wrap;
    overflow-wrap: anywhere;
    font-family: var(--font-korean);
  }
  .tail {
    height: 100%;
  }
  :global(.resume) {
    position: absolute;
    top: 8px;
    left: 50%;
    transform: translateX(-50%);
    z-index: 2;
  }
</style>
