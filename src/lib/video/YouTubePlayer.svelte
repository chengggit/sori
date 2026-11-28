<script lang="ts">
  import { onMount } from "svelte";
  import { trackPlayback } from "$lib/dashboard/playback";
  import type { PlaybackEvents } from "./playback";
  let {
    id,
    title,
    start,
    events,
  }: { id: string; title: string; start: number; events: PlaybackEvents } = $props();
  let frame: HTMLIFrameElement;
  onMount(() => {
    const tracker = trackPlayback(frame, {
      ...events,
      onControls: (controls) => {
        events.onControls(controls);
        if (controls && start > 0) controls.seek(start);
      },
    });
    return () => tracker.destroy();
  });
</script>

<iframe
  bind:this={frame}
  src={`https://www.youtube.com/embed/${id}?enablejsapi=1`}
  {title}
  allow="accelerometer; autoplay; encrypted-media; picture-in-picture"
  allowfullscreen
  data-testid="youtube-player"
></iframe>

<style>
  iframe {
    width: 100%;
    height: 100%;
    border: 0;
  }
</style>
