<script lang="ts">
  import { onMount } from "svelte";
  import { fly } from "svelte/transition";
  import { BookOpen, Bookmark, X } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { displayWord, partOfSpeech, capitalize, savedDate } from "./entries";
  import { normalizeDisplayText } from "$lib/text";
  import { openExternal } from "$lib/dictionary/lookup";
  import { ui } from "$lib/ui-state.svelte";
  import type { VocabularyEntry } from "./types";
  let {
    entry,
    width = $bindable(500),
    onClose,
    onEdit,
    onRemove,
  }: {
    entry: VocabularyEntry;
    width?: number;
    onClose: () => void;
    onEdit: () => void;
    onRemove: () => void;
  } = $props();
  let maximum = $state(900);
  let minimum = $derived(Math.min(320, maximum));
  let displayedWidth = $derived(Math.max(minimum, Math.min(width, maximum)));
  let close: HTMLButtonElement | null = $state(null);
  let error = $state("");
  let dragging = false,
    startX = 0,
    startWidth = 0;
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  onMount(() => {
    close?.focus();
    const main = document.querySelector('[data-testid="page-content"]');
    if (!main) return;
    const observer = new ResizeObserver(
      ([entry]) => (maximum = Math.max(240, entry.contentRect.width * 0.7)),
    );
    observer.observe(main);
    return () => observer.disconnect();
  });
  async function openSource() {
    if (!entry.definition?.sourceUrl) return;
    const reply = await openExternal(entry.definition.sourceUrl);
    error = reply.ok ? "" : reply.error;
  }
</script>

<aside
  class="word-details"
  style:width={`${displayedWidth}px`}
  aria-label="Word details"
  data-testid="vocabulary-details"
  transition:fly={{ x: 500, duration: reduced ? 0 : 240, opacity: 1 }}
>
  <!-- A focusable ARIA separator implements the window-splitter keyboard pattern. -->
  <!-- svelte-ignore a11y_no_noninteractive_tabindex, a11y_no_noninteractive_element_interactions -->
  <div
    class="resize"
    role="separator"
    aria-label="Resize word details"
    aria-orientation="vertical"
    aria-valuemin={Math.round(minimum)}
    aria-valuemax={Math.round(maximum)}
    aria-valuenow={Math.round(displayedWidth)}
    tabindex="0"
    onpointerdown={(event) => {
      dragging = true;
      startX = event.clientX;
      startWidth = displayedWidth;
      event.currentTarget.setPointerCapture(event.pointerId);
    }}
    onpointermove={(event) => {
      if (dragging)
        width = Math.max(
          minimum,
          Math.min(maximum, startWidth - (event.clientX - startX) / ui.pageScale),
        );
    }}
    onpointerup={() => (dragging = false)}
    onpointercancel={() => (dragging = false)}
    onkeydown={(event) => {
      if (["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) {
        event.preventDefault();
        width =
          event.key === "Home"
            ? minimum
            : event.key === "End"
              ? maximum
              : Math.max(
                  minimum,
                  Math.min(maximum, displayedWidth + (event.key === "ArrowLeft" ? 16 : -16)),
                );
      }
    }}
  ></div>
  <header>
    <p>Word details</p>
    <Button
      bind:ref={close}
      variant="ghost"
      size="icon-sm"
      aria-label="Close word details"
      onclick={onClose}
    >
      <X size={16} />
    </Button>
  </header>
  <div class="details-body">
    <h2 lang="ko">{displayWord(entry)}</h2>
    {#if entry.definition?.hanja || partOfSpeech(entry)}<p class="metadata">
        {[entry.definition?.hanja, capitalize(partOfSpeech(entry))].filter(Boolean).join(" · ")}
      </p>{/if}
    <section>
      <h3>Definition</h3>
      <p class="definition" class:empty={!entry.definition?.text}>
        {entry.definition?.text || "No definition saved."}
      </p>
      {#if entry.definition?.note}<p class="note">{entry.definition.note}</p>{/if}
      {#if entry.definition?.sourceUrl?.startsWith("https://")}<button
          class="mt-3 text-xs text-muted-foreground underline"
          onclick={openSource}
        >
          Dictionary source
        </button>{/if}
    </section>
    {#if entry.context}<section>
        <h3>Context</h3>
        <p lang="ko" class="context">{normalizeDisplayText(entry.context)}</p>
      </section>{/if}
    {#if entry.tags.length}<section>
        <h3>Tags</h3>
        <ul class="tags">
          {#each entry.tags as tag, index (index)}<li>{tag}</li>{/each}
        </ul>
      </section>{/if}
    <section>
      <h3>Source</h3>
      <p class="source">
        {#if entry.documentId != null}<BookOpen size={15} />{:else}<Bookmark size={15} />{/if}<span>
          {normalizeDisplayText(entry.sourceTitle || "Saved word")}
        </span>
      </p>
      {#if savedDate(entry.createdAt)}<p class="date">Saved {savedDate(entry.createdAt)}</p>{/if}
    </section>
    {#if error}<p class="text-sm text-destructive" role="alert">{error}</p>{/if}
  </div>
  <footer>
    <Button variant="outline" size="sm" onclick={onEdit}>Edit</Button><Button
      variant="ghost"
      size="sm"
      class="text-destructive"
      onclick={onRemove}
    >
      Remove
    </Button>
  </footer>
</aside>

<style>
  .word-details {
    position: fixed;
    top: 3.5rem;
    right: 0;
    height: calc(var(--app-height) - 3.5rem);
    background: var(--card);
    border-left: 1px solid var(--border);
    z-index: 20;
    display: flex;
    flex-direction: column;
    max-width: 100%;
  }
  header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 18px 18px 14px 24px;
    flex-shrink: 0;
  }
  header p {
    font-size: 13px;
    font-weight: 500;
    color: var(--muted-foreground);
  }
  .details-body {
    overflow: auto;
    padding: 6px 24px 32px;
    flex: 1;
    min-height: 0;
    overflow-wrap: anywhere;
  }
  h2 {
    font-family: var(--font-korean);
    font-size: 24px;
    font-weight: 600;
    line-height: 1.4;
  }
  .metadata {
    margin-top: 8px;
    font-size: 13px;
    color: var(--muted-foreground);
  }
  section {
    border-top: 1px solid var(--border);
    margin-top: 22px;
    padding-top: 18px;
  }
  h3 {
    font-size: 13px;
    font-weight: 500;
    margin-bottom: 8px;
  }
  .definition {
    font-size: 14px;
    line-height: 22px;
    white-space: pre-wrap;
  }
  .empty,
  .note {
    color: var(--muted-foreground);
  }
  .note {
    margin-top: 8px;
    font-size: 13px;
    line-height: 20px;
    white-space: pre-wrap;
  }
  .context {
    font-family: var(--font-korean);
    font-size: 14px;
    line-height: 23px;
    white-space: pre-wrap;
  }
  .source {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    font-size: 14px;
  }
  .source :global(svg) {
    flex-shrink: 0;
    margin-top: 2px;
    color: var(--muted-foreground);
  }
  .date {
    margin-top: 6px;
    font-size: 12px;
    color: var(--muted-foreground);
  }
  .tags {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
  }
  .tags li {
    background: var(--neutral-hover);
    padding: 3px 8px;
    border-radius: 999px;
    font-size: 12px;
  }
  footer {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    padding: 12px 24px;
    border-top: 1px solid var(--border);
  }
  .resize {
    position: absolute;
    left: -4px;
    top: 0;
    width: 8px;
    height: 100%;
    cursor: col-resize;
    touch-action: none;
  }
</style>
