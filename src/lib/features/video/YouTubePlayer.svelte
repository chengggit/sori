<script lang="ts">
  import { trackPlayback } from "../dashboard/playback";
  import type { PlaybackEvents } from "./playback";

  let {
    id,
    title,
    start,
    events,
  }: {
    id: string;
    title: string;
    start: number;
    events: PlaybackEvents;
  } = $props();
</script>

<iframe
  class="block aspect-video min-h-[200px] w-full rounded-xl bg-black"
  {title}
  src={`https://www.youtube.com/embed/${id}?cc_lang_pref=ko&enablejsapi=1&start=${start}`}
  use:trackPlayback={events}
  referrerpolicy="strict-origin-when-cross-origin"
  allow="encrypted-media; picture-in-picture; fullscreen"
  allowfullscreen
></iframe>
