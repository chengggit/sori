<script lang="ts">
  import VideoCard from "./VideoCard.svelte";
  import type { YouTubeVideo } from "./commands";
  let { videos, from }: { videos: YouTubeVideo[]; from?: "explore" } = $props();
</script>

<div class="video-grid">
  {#each videos as video (video.id)}<VideoCard {video} {from} />{/each}
</div>

<style>
  .video-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 26px 20px;
  }
  @media (max-width: 1250px) {
    .video-grid {
      grid-template-columns: repeat(3, minmax(0, 1fr));
    }
  }
  @media (max-width: 1000px) {
    .video-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }
  @media (max-width: 600px) {
    .video-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
