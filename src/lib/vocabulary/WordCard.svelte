<script lang="ts">
  import { EllipsisVertical, Pencil, Trash2 } from "@lucide/svelte";
  import { DropdownMenu } from "bits-ui";
  import { Button } from "$lib/components/ui/button";
  import { partOfSpeech, displayWord, formatMeaning } from "./entries";
  import type { VocabularyEntry } from "./types";
  let {
    entry,
    busy,
    onDetails,
    onEdit,
    onRemove,
  }: {
    entry: VocabularyEntry;
    busy: boolean;
    onDetails: (event: MouseEvent) => void;
    onEdit: (trigger: HTMLButtonElement | null) => void;
    onRemove: (trigger: HTMLButtonElement | null) => void;
  } = $props();
  let handingOff = false;
  let trigger: HTMLButtonElement | null = $state(null);
</script>

<article class="word-card" data-testid={`word-card-${entry.id}`}>
  <button
    class="open-word"
    data-testid={`vocabulary-${entry.id}`}
    aria-label={`Open details for ${displayWord(entry)}`}
    onclick={onDetails}
  >
    <span class="heading">
      <span class="word" lang="ko">{displayWord(entry)}</span>{#if entry.definition?.hanja}<span
          class="hanja"
        >
          {entry.definition.hanja}
        </span>{/if}{#if partOfSpeech(entry)}<span class="type">{partOfSpeech(entry)}</span>{/if}
    </span>
    {#if formatMeaning(entry)}<span class="meaning">
        {formatMeaning(entry)}
      </span>{:else if entry.context}<span class="meaning context" lang="ko">
        {entry.context.normalize("NFC")}
      </span>{/if}
    {#if entry.definition?.note}<span class="note">{entry.definition.note}</span>{/if}
  </button>
  <div class="actions">
    <DropdownMenu.Root>
      <DropdownMenu.Trigger disabled={busy}>
        {#snippet child({ props })}<Button
            bind:ref={trigger}
            {...props}
            variant="ghost"
            size="icon-sm"
            class="border-0 shadow-none"
            aria-label={`More actions for ${displayWord(entry)}`}
          >
            <EllipsisVertical size={14} />
          </Button>{/snippet}
      </DropdownMenu.Trigger>
      <DropdownMenu.Portal>
        <DropdownMenu.Content
          align="end"
          sideOffset={4}
          onCloseAutoFocus={(event) => {
            if (handingOff) {
              event.preventDefault();
              handingOff = false;
            }
          }}
          class="z-50 min-w-36 rounded-lg bg-card p-1 text-foreground shadow-md outline-none"
        >
          <DropdownMenu.Item
            class="vocabulary-menu-item"
            onSelect={() => {
              handingOff = true;
              onEdit(trigger);
            }}
          >
            <Pencil size={15} />Edit
          </DropdownMenu.Item>
          <DropdownMenu.Item
            class="vocabulary-menu-item text-destructive"
            onSelect={() => {
              handingOff = true;
              onRemove(trigger);
            }}
          >
            <Trash2 size={15} />Remove
          </DropdownMenu.Item>
        </DropdownMenu.Content>
      </DropdownMenu.Portal>
    </DropdownMenu.Root>
  </div>
</article>

<style>
  .word-card {
    display: flex;
    gap: 12px;
    align-items: flex-start;
    border-radius: 12px;
    background: var(--card);
    transition: background 120ms;
  }
  .word-card:hover,
  .word-card:focus-within {
    background: var(--neutral-hover);
  }
  .open-word {
    flex: 1;
    min-width: 0;
    display: grid;
    gap: 6px;
    text-align: left;
    padding: 16px 0 16px 20px;
    border-radius: 12px;
  }
  .heading {
    display: flex;
    gap: 8px;
    align-items: center;
    min-width: 0;
  }
  .word {
    font-family: var(--font-korean);
    font-size: 17px;
    font-weight: 600;
    max-width: 60%;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .hanja {
    font-size: 13px;
    color: var(--muted-foreground);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 25%;
  }
  .type {
    font-size: 12px;
    border-radius: 999px;
    padding: 2px 7px;
    background: var(--neutral-hover);
    color: var(--muted-foreground);
    flex-shrink: 0;
  }
  .meaning {
    font-size: 14px;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    overflow-wrap: anywhere;
  }
  .context {
    color: var(--muted-foreground);
    font-family: var(--font-korean);
    font-size: 13px;
  }
  .note {
    font-size: 12px;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
    color: var(--muted-foreground);
  }
  .actions {
    margin: 16px 16px 0 0;
    flex-shrink: 0;
  }
  :global(.vocabulary-menu-item) {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 10px;
    border-radius: 6px;
    font-size: 14px;
    cursor: pointer;
  }
  :global(.vocabulary-menu-item[data-highlighted]) {
    background: var(--neutral-hover);
  }
  @media (prefers-reduced-motion: reduce) {
    .word-card {
      transition: none;
    }
  }
</style>
