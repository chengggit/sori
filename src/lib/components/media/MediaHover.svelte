<script lang="ts">
  import { BookOpen, Play } from "@lucide/svelte";
  import type { Snippet } from "svelte";
  let {
    children,
    icon = "play",
    active = false,
    fit = "cover",
  }: {
    children: Snippet;
    icon?: "play" | "book";
    active?: boolean;
    fit?: "cover" | "contain";
  } = $props();
</script>

<div class="media-hover" class:active style:--media-fit={fit}>
  <div class="artwork">{@render children()}</div>
  <span class="thumbnail-overlay" aria-hidden="true">
    <span class="play-badge">
      {#if icon === "book"}<BookOpen size={22} strokeWidth={1.5} />{:else}<Play
          size={22}
          fill="currentColor"
          strokeWidth={1.5}
        />{/if}
    </span>
  </span>
</div>

<style>
  .media-hover {
    position: relative;
    width: 100%;
    height: 100%;
    overflow: hidden;
    border-radius: inherit;
    color: var(--dashboard-accent);
  }
  .artwork {
    position: relative;
    display: grid;
    place-items: center;
    width: 100%;
    height: 100%;
    transition: transform 200ms ease;
  }
  .artwork :global(img) {
    display: block;
    width: 100%;
    height: 100%;
    object-fit: var(--media-fit);
  }
  .thumbnail-overlay {
    position: absolute;
    inset: 0;
    display: grid;
    place-items: center;
    background: color-mix(in oklch, black 38%, transparent);
    opacity: 0;
    transition: opacity 200ms ease;
    pointer-events: none;
  }
  .play-badge {
    display: grid;
    place-items: center;
    width: 46px;
    height: 46px;
    border-radius: 50%;
    background: #fff;
    color: var(--dashboard-accent);
    box-shadow: 0 2px 10px rgb(0 0 0 / 25%);
    transform: scale(0.82);
    transition: transform 200ms ease;
  }
  .active .artwork,
  :global([data-media-focus]:hover) .artwork,
  :global([data-media-focus]:focus-within) .artwork {
    transform: scale(1.03);
  }
  .active .thumbnail-overlay,
  :global([data-media-focus]:hover) .thumbnail-overlay,
  :global([data-media-focus]:focus-within) .thumbnail-overlay {
    opacity: 1;
  }
  .active .play-badge,
  :global([data-media-focus]:hover) .play-badge,
  :global([data-media-focus]:focus-within) .play-badge {
    transform: scale(1);
  }
  @media (prefers-reduced-motion: reduce) {
    .artwork,
    .thumbnail-overlay,
    .play-badge {
      transition: none;
    }
  }
</style>
