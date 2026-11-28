<script lang="ts">
  import { Film } from "@lucide/svelte";
  import MediaHover from "$lib/components/media/MediaHover.svelte";
  import type { YouTubeVideo } from "./commands";
  let { video, from }: { video: YouTubeVideo; from?: "explore" } = $props();
  let failed = $state(false);
</script>

<a
  data-media-focus
  class="video-card"
  href={`#/watch?v=${encodeURIComponent(video.id)}${from ? `&from=${from}` : ""}`}
>
  <div class="video-thumbnail">
    <MediaHover>
      {#if !failed}<img
          src={video.thumbnail}
          alt=""
          loading="lazy"
          referrerpolicy="no-referrer"
          onerror={() => (failed = true)}
        />{:else}<Film size={30} aria-hidden="true" />{/if}
    </MediaHover>
  </div>
  <h3 class="mt-2 line-clamp-2 text-sm font-medium" title={video.title} lang="ko">
    {video.title.normalize("NFC")}
  </h3>
  <p class="mt-1 truncate text-xs text-muted-foreground">{video.channel.normalize("NFC")}</p>
</a>

<style>
  .video-card {
    display: block;
    min-width: 0;
  }
  .video-thumbnail {
    aspect-ratio: 16/9;
    position: relative;
    overflow: hidden;
    background: var(--chip);
    border-radius: 12px;
  }
</style>
