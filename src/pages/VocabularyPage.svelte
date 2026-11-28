<script lang="ts">
  import { onMount, tick } from "svelte";
  import { Bookmark, Search, ArrowUpDown, X } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import * as Sheet from "$lib/components/ui/sheet";
  import WordCard from "$lib/vocabulary/WordCard.svelte";
  import WordDetails from "$lib/vocabulary/WordDetails.svelte";
  import WordForm from "$lib/vocabulary/WordForm.svelte";
  import { VocabularyModel } from "$lib/vocabulary/state.svelte";
  import { displayWord } from "$lib/vocabulary/entries";
  import { sortOptions, type VocabularyEntry, type WordDraft } from "$lib/vocabulary/types";
  import { platform } from "../platform";

  const vocabulary = new VocabularyModel();
  let editing = $state<VocabularyEntry | null>(null),
    removing = $state<VocabularyEntry | null>(null);
  let editorOpen = $state(false),
    removalOpen = $state(false);
  let panelWidth = $state(500);
  let search: HTMLInputElement | null = $state(null);
  let detailTrigger: HTMLElement | null = null;
  let dialogTrigger: HTMLElement | null = null;
  onMount(() => {
    void vocabulary.load();
    const unsubscribe = platform.onEvent("library-changed", () => void vocabulary.load());
    return () => {
      vocabulary.dispose();
      unsubscribe();
    };
  });
  function closeDetails() {
    vocabulary.selectedId = null;
    void tick().then(() => {
      if (detailTrigger?.isConnected) detailTrigger.focus();
      else search?.focus();
    });
  }
  function edit(entry: VocabularyEntry, trigger = document.activeElement) {
    dialogTrigger = trigger instanceof HTMLElement ? trigger : null;
    editing = entry;
    vocabulary.editError = "";
    editorOpen = true;
  }
  function remove(entry: VocabularyEntry, trigger = document.activeElement) {
    dialogTrigger = trigger instanceof HTMLElement ? trigger : null;
    removing = entry;
    vocabulary.removeError = "";
    removalOpen = true;
  }
  function restoreDialogFocus(event: Event) {
    event.preventDefault();
    void tick().then(() => {
      if (dialogTrigger?.isConnected) dialogTrigger.focus();
      else search?.focus();
    });
  }
  function initial(entry: VocabularyEntry): WordDraft {
    return {
      word: entry.normalizedForm ?? "",
      meaning: entry.definition?.text ?? "",
      note: entry.definition?.note ?? "",
      tags: entry.tags,
    };
  }
</script>

<svelte:window
  onkeydown={(event) => {
    if (
      event.key === "Escape" &&
      !event.defaultPrevented &&
      vocabulary.selected &&
      !editorOpen &&
      !removalOpen
    ) {
      event.preventDefault();
      closeDetails();
    }
  }}
/>
<div class="vocabulary-page" data-testid="vocabulary-page">
  <p class="count" data-testid="vocabulary-count">{vocabulary.countLabel}</p>
  <div class="filters">
    <div class="search-field">
      <Search size={16} aria-hidden="true" /><Input
        bind:ref={search}
        aria-label="Search vocabulary"
        placeholder="Search vocabulary…"
        bind:value={vocabulary.query}
      />
    </div>
    <select aria-label="Filter by type" bind:value={vocabulary.typeFilter}>
      {#each vocabulary.types as type (type)}<option value={type}>{type}</option>{/each}
    </select>
    <div class="sort-field">
      <ArrowUpDown size={14} aria-hidden="true" /><select
        aria-label="Sort vocabulary"
        bind:value={vocabulary.sort}
      >
        {#each sortOptions as sort (sort)}<option value={sort}>{sort}</option>{/each}
      </select>
    </div>
  </div>
  {#if vocabulary.error}<div role="alert" class="load-error" data-testid="vocabulary-error">
      <p>{vocabulary.error}</p>
      <Button
        variant="outline"
        size="sm"
        disabled={vocabulary.refreshing}
        onclick={() => void vocabulary.load()}
      >
        Retry
      </Button>
    </div>{/if}
  {#if vocabulary.loading}<p class="text-sm text-muted-foreground" role="status">
      Loading saved words…
    </p>{/if}
  {#if vocabulary.filtered.length}<ul class="word-list" data-testid="vocabulary-list">
      {#each vocabulary.filtered as entry (entry.id)}<li>
          <WordCard
            {entry}
            busy={vocabulary.busy}
            onDetails={(event) => {
              detailTrigger = event.currentTarget as HTMLElement;
              vocabulary.selectedId = entry.id;
            }}
            onEdit={(trigger) => edit(entry, trigger)}
            onRemove={(trigger) => remove(entry, trigger)}
          />
        </li>{/each}
    </ul>
  {:else if !vocabulary.loading && !vocabulary.error}<div class="empty" data-testid="empty-vocabulary">
      {#if !vocabulary.entries.length}<Bookmark size={32} />
        <h2>No saved words yet</h2>
        <p>Save a word from Reader or a video to see it here.</p>{:else}<Search size={32} />
        <h2>No words match your search and filters.</h2>
        <Button
          variant="secondary"
          size="sm"
          onclick={() => {
            vocabulary.clearFilters();
            search?.focus();
          }}
        >
          <X size={14} />Clear filters
        </Button>{/if}
    </div>{/if}
</div>
{#if vocabulary.selected}<WordDetails
    entry={vocabulary.selected}
    bind:width={panelWidth}
    onClose={closeDetails}
    onEdit={() => vocabulary.selected && edit(vocabulary.selected)}
    onRemove={() => vocabulary.selected && remove(vocabulary.selected)}
  />{/if}

<Sheet.Root bind:open={editorOpen}>
  <Sheet.Content
    showCloseButton={!vocabulary.busy}
    onCloseAutoFocus={restoreDialogFocus}
    class="max-w-[500px] rounded-2xl border-transparent gap-0 pb-0"
    overlayProps={{ style: "backdrop-filter:none;" }}
    onEscapeKeydown={(event) => {
      if (vocabulary.busy) event.preventDefault();
    }}
    onInteractOutside={(event) => {
      if (vocabulary.busy) event.preventDefault();
    }}
  >
    <Sheet.Header>
      <Sheet.Title class="text-lg">Edit saved word</Sheet.Title><Sheet.Description class="sr-only">
        Update the dictionary form, meaning, tags and note for this saved selection.
      </Sheet.Description>
    </Sheet.Header>
    <div class="px-5 pb-5" data-testid="vocabulary-editor">
      {#if editing}{#key editing.id}<WordForm
            mode="edit"
            saved
            initial={initial(editing)}
            saving={vocabulary.busy}
            error={vocabulary.editError}
            onSave={(draft) => vocabulary.save(editing!.id, draft)}
            onClose={() => (editorOpen = false)}
          />{/key}{/if}
    </div>
  </Sheet.Content>
</Sheet.Root>
<Sheet.Root bind:open={removalOpen}>
  <Sheet.Content
    showCloseButton={!vocabulary.busy}
    onCloseAutoFocus={restoreDialogFocus}
    class="max-w-[380px] rounded-2xl border-transparent gap-0 pb-0"
    overlayProps={{ style: "backdrop-filter:none;" }}
    onEscapeKeydown={(event) => {
      if (vocabulary.busy) event.preventDefault();
    }}
    onInteractOutside={(event) => {
      if (vocabulary.busy) event.preventDefault();
    }}
  >
    <Sheet.Header>
      <Sheet.Title>Remove saved word?</Sheet.Title><Sheet.Description>
        Remove “{removing ? displayWord(removing) : ""}” from Vocabulary?
      </Sheet.Description>
    </Sheet.Header>
    <div class="px-5 pb-5" data-testid="vocabulary-delete">
      {#if vocabulary.removeError}<p role="alert" class="mb-4 text-sm text-destructive">
          {vocabulary.removeError}
        </p>{/if}
      <div class="flex justify-end gap-2">
        <Button variant="outline" disabled={vocabulary.busy} onclick={() => (removalOpen = false)}>
          Cancel
        </Button><Button
          disabled={vocabulary.busy}
          onclick={async () => {
            if (removing && (await vocabulary.remove(removing.id))) {
              removalOpen = false;
              void tick().then(() => search?.focus());
            }
          }}
        >
          Remove
        </Button>
      </div>
    </div>
  </Sheet.Content>
</Sheet.Root>

<style>
  .count {
    color: var(--muted-foreground);
    font-size: 13px;
    margin-bottom: 14px;
  }
  .filters {
    display: flex;
    gap: 8px;
    margin-bottom: 14px;
    align-items: center;
    flex-wrap: wrap;
  }
  .search-field {
    position: relative;
    flex: 1;
    min-width: 200px;
  }
  .search-field :global(svg) {
    position: absolute;
    left: 12px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--muted-foreground);
    pointer-events: none;
    z-index: 1;
  }
  .search-field :global(input) {
    padding-left: 36px;
    border-radius: 10px;
    height: 38px;
  }
  select {
    width: 132px;
    height: 38px;
    border: 1px solid var(--border);
    border-radius: 8px;
    background: var(--card);
    padding: 0 10px;
    font-size: 13px;
  }
  .sort-field {
    position: relative;
  }
  .sort-field :global(svg) {
    position: absolute;
    top: 12px;
    left: 10px;
    pointer-events: none;
    color: var(--muted-foreground);
  }
  .sort-field select {
    padding-left: 30px;
  }
  .word-list {
    display: grid;
    gap: 8px;
  }
  .load-error {
    display: flex;
    gap: 12px;
    align-items: center;
    flex-wrap: wrap;
    margin-bottom: 14px;
    font-size: 14px;
    color: var(--destructive);
  }
  .empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    gap: 12px;
    min-height: 288px;
    padding: 24px;
    color: var(--muted-foreground);
  }
  .empty h2 {
    font-weight: 600;
    color: var(--foreground);
  }
  .empty p {
    font-size: 14px;
  }
</style>
