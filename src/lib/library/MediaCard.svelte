<script lang="ts">
  import { EllipsisVertical, Film, Pencil, Trash2 } from "@lucide/svelte";
  import MediaHover from "$lib/components/media/MediaHover.svelte";
  import { DropdownMenu } from "bits-ui";
  import { Button } from "$lib/components/ui/button";
  import type { DocumentSummary, VideoSummary } from "./commands";
  import { normalizeDisplayText } from "$lib/text";
  import { formatTime } from "$lib/video/time";
  let {
    item,
    video = false,
    busy = false,
    onEdit,
    onRemove,
  }: {
    item: DocumentSummary | VideoSummary;
    video?: boolean;
    busy?: boolean;
    onEdit?: () => void;
    onRemove: () => void;
  } = $props();
  let failed = $state(false);
  let menuOpen = $state(false);
  let openingDialog = false;
  const media = $derived(item as VideoSummary);
  const title = $derived(normalizeDisplayText(video ? media.displayTitle || item.title : item.title));
  const thumbnail = $derived(
    video && media.thumbnailUrl ? `sori-thumbnail://video/${item.id}.jpg` : "",
  );
  $effect(() => {
    thumbnail;
    failed = false;
  });
  const progress = $derived(
    media.duration > 0 ? Math.min(100, Math.max(0, (media.seconds / media.duration) * 100)) : 0,
  );
</script>

<article data-media-focus class="media-card" class:video class:menu-open={menuOpen}>
  <a
    class="open-card"
    href={video ? `#/watch?id=${item.id}` : `#/reader?id=${item.id}`}
    data-testid={`${video ? "open-video" : "open-document"}-${item.id}`}
    aria-label={`Open ${title}`}
  >
    <div class="cover">
      <MediaHover icon={video ? "play" : "book"} active={menuOpen} fit="contain">
        {#if video}
          {#if thumbnail && !failed}<img
              src={thumbnail}
              alt=""
              loading="lazy"
              onerror={() => (failed = true)}
            />{:else}<span class="fallback-film"><Film size={36} aria-hidden="true" /></span>{/if}
        {:else}
          <span class="watermark" aria-hidden="true">
            {Array.from(title.trim())[0]?.toLocaleUpperCase()}
          </span>
          <span class="type-badge">{(item as DocumentSummary).pdf ? "PDF" : "TEXT"}</span>
        {/if}
      </MediaHover>
      {#if video && media.duration > 0}<span
          class="progress-track"
          role="progressbar"
          aria-label={`Progress for ${title}`}
          aria-valuenow={Math.round(progress)}
          aria-valuemin={0}
          aria-valuemax={100}
        >
          <span style:width={`${progress}%`}></span>
        </span>{/if}
    </div>
    <h3 {title}>{title}</h3>
    {#if video}<p class="metadata">
        {media.duration > 0
          ? `${media.seconds > 0 ? `${formatTime(media.seconds)} / ` : ""}${formatTime(media.duration)}`
          : media.seconds > 0
            ? `${formatTime(media.seconds)} watched`
            : "Not started"}
      </p>{/if}
  </a>
  <div class="actions">
    <DropdownMenu.Root bind:open={menuOpen}>
      <DropdownMenu.Trigger disabled={busy}>
        {#snippet child({ props })}<Button
            {...props}
            variant="ghost"
            class="border-0 bg-card shadow-none hover:bg-neutral-hover"
            size="icon-sm"
            aria-label={`Actions for ${title}`}
          >
            <EllipsisVertical size={16} />
          </Button>{/snippet}
      </DropdownMenu.Trigger>
      <DropdownMenu.Portal>
        <DropdownMenu.Content
          align="end"
          sideOffset={5}
          onCloseAutoFocus={(event) => {
            if (openingDialog) {
              event.preventDefault();
              openingDialog = false;
            }
          }}
          class="z-50 min-w-36 rounded-lg border border-border bg-popover p-1 text-popover-foreground shadow-md outline-none"
        >
          {#if onEdit}<DropdownMenu.Item
              disabled={busy}
              onSelect={() => {
                openingDialog = true;
                onEdit?.();
              }}
              class="menu-item"
            >
              <Pencil size={15} />Edit
            </DropdownMenu.Item>{/if}
          <DropdownMenu.Item
            disabled={busy}
            onSelect={() => {
              openingDialog = true;
              onRemove();
            }}
            class="menu-item text-destructive"
          >
            <Trash2 size={15} />{video ? "Remove" : "Delete"}
          </DropdownMenu.Item>
        </DropdownMenu.Content>
      </DropdownMenu.Portal>
    </DropdownMenu.Root>
  </div>
</article>

<style>
  .media-card {
    position: relative;
    min-width: 0;
  }
  .open-card {
    display: block;
    border-radius: 12px;
  }
  .cover {
    position: relative;
    aspect-ratio: 3 / 4;
    border-radius: 12px;
    overflow: hidden;
    background: var(--hero);
  }
  .video .cover {
    aspect-ratio: 16 / 9;
    background: black;
  }
  .watermark {
    position: absolute;
    right: 18px;
    top: 50%;
    transform: translateY(-50%);
    font-size: 180px;
    font-weight: 300;
    line-height: 1;
    color: var(--dashboard-accent);
    opacity: 0.23;
  }
  .type-badge {
    position: absolute;
    top: 12px;
    left: 12px;
    padding: 2px 7px;
    border-radius: 20px;
    background: var(--card);
    color: var(--dashboard-accent);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.5px;
  }
  .actions {
    position: absolute;
    right: 8px;
    top: 8px;
    z-index: 1;
    opacity: 0;
    transition: opacity 180ms ease;
  }
  .fallback-film {
    position: absolute;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
    color: var(--dashboard-accent);
  }
  .media-card:hover .actions,
  .media-card:focus-within .actions,
  .menu-open .actions {
    opacity: 1;
  }
  h3 {
    margin-top: 8px;
    font-size: 13px;
    font-weight: 600;
    line-height: 1.5;
    font-family: var(--font-korean);
    word-break: keep-all;
    overflow-wrap: anywhere;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .media-card:not(.video) h3 {
    font-size: 14px;
  }
  .metadata {
    margin-top: 4px;
    color: var(--muted-foreground);
    font-size: 12px;
  }
  .progress-track {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 4px;
  }
  .progress-track > span {
    display: block;
    height: 100%;
    background: var(--dashboard-progress);
  }
  :global(.menu-item) {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 7px 9px;
    border-radius: 5px;
    font-size: 13px;
    cursor: pointer;
    outline: none;
  }
  :global(.menu-item[data-highlighted]) {
    background: var(--neutral-hover);
  }
  @media (hover: none) {
    .actions {
      opacity: 1;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .actions {
      transition: none;
    }
  }
</style>
