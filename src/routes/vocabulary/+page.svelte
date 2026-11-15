<script lang="ts">
  import { EllipsisVertical, Pencil, Search, Trash2 } from "@lucide/svelte";
  import { isTauri } from "@tauri-apps/api/core";
  import { DropdownMenu } from "bits-ui";
  import { onMount } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import * as Sheet from "$lib/components/ui/sheet";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import { dictionaryLicense } from "$lib/features/dictionary/dictionary";
  import {
    editVocabulary,
    listVocabulary,
    removeVocabulary,
    type VocabularyEntry,
  } from "$lib/features/vocabulary/vocabulary";

  let entries = $state<VocabularyEntry[]>([]);
  let query = $state("");
  let search = $derived(query.trim().normalize().toLowerCase());
  let visibleEntries = $derived(
    entries.filter(({ word, normalizedForm }) =>
      (normalizedForm ?? word).normalize().toLowerCase().includes(search),
    ),
  );
  let desktop = $state(false);
  let loading = $state(true);
  let loadError = $state("");
  let pendingRemoval = $state<VocabularyEntry>();
  let removing = $state(false);
  let removeError = $state("");
  let editing = $state<VocabularyEntry>();
  let normalizedForm = $state("");
  let meaning = $state("");
  let note = $state("");
  let tags = $state("");
  let saving = $state(false);
  let editError = $state("");

  onMount(() => {
    desktop = isTauri();
    if (desktop) void loadEntries();
    else loading = false;
  });

  async function loadEntries() {
    loading = true;
    loadError = "";
    try {
      entries = await listVocabulary();
    } catch (cause) {
      loadError = String(cause);
    } finally {
      loading = false;
    }
  }

  function startEdit(entry: VocabularyEntry) {
    normalizedForm = entry.normalizedForm ?? entry.word;
    meaning = entry.definition?.text ?? "";
    note = entry.definition?.note ?? "";
    tags = entry.tags.join(", ");
    editError = "";
    editing = entry;
  }

  async function saveEdit(event: SubmitEvent) {
    event.preventDefault();
    if (!editing || saving || !normalizedForm.trim()) return;
    saving = true;
    editError = "";
    try {
      const updated = await editVocabulary(editing.id, {
        normalizedForm,
        meaning,
        note,
        tags: [
          ...new Set(
            tags
              .split(",")
              .map((tag) => tag.trim())
              .filter(Boolean),
          ),
        ],
      });
      entries = entries.map((entry) => (entry.id === updated.id ? updated : entry));
      editing = undefined;
    } catch (cause) {
      editError = String(cause);
    } finally {
      saving = false;
    }
  }

  async function confirmRemoval() {
    if (!pendingRemoval || removing) return;
    const { id } = pendingRemoval;
    removing = true;
    removeError = "";
    try {
      await removeVocabulary(id);
      entries = entries.filter((entry) => entry.id !== id);
      pendingRemoval = undefined;
    } catch (cause) {
      removeError = String(cause);
    } finally {
      removing = false;
    }
  }
</script>

<svelte:head>
  <title>Vocabulary · Sori</title>
</svelte:head>

<header class="border-b">
  <div class="mx-auto flex h-14 max-w-6xl items-center gap-2 px-4 sm:px-6 lg:px-8">
    <Sidebar.Trigger class="md:hidden" />
    <h1 class="text-base font-semibold">Vocabulary</h1>
    {#if desktop && !loading && !loadError}
      <span class="text-sm text-muted-foreground">
        {entries.length} saved
      </span>
    {/if}
  </div>
</header>

<div class="mx-auto max-w-6xl px-4 py-5 sm:px-6 lg:px-8">
  {#if loading}
    <p class="text-sm text-muted-foreground" role="status">Loading saved words…</p>
  {:else if !desktop}
    <p class="text-sm text-muted-foreground">Open Sori on desktop to view your saved words.</p>
  {:else if loadError}
    <p class="mb-3 text-sm text-destructive" role="alert">Could not load vocabulary. {loadError}</p>
    <Button variant="outline" size="sm" onclick={loadEntries}>Try again</Button>
  {:else if !entries.length}
    <p class="text-sm text-muted-foreground">Save a word from the reader to see it here.</p>
  {:else}
    <div class="relative mb-4 max-w-sm">
      <Search class="pointer-events-none absolute top-2.5 left-3 size-4 text-muted-foreground" />
      <Input
        type="search"
        bind:value={query}
        aria-label="Search saved words"
        placeholder="Search saved words"
        class="pl-9"
      />
    </div>

    {#if visibleEntries.length}
      <ul class="grid gap-3">
        {#each visibleEntries as entry (entry.id)}
          {@const savedWord = entry.normalizedForm ?? entry.word}
          <li class="rounded-xl border bg-card p-4 text-card-foreground">
            <div class="flex items-start justify-between gap-3">
              <h2 class="min-w-0 wrap-anywhere text-lg font-semibold">
                <span lang="ko">{savedWord}</span>
              </h2>
              <DropdownMenu.Root>
                <DropdownMenu.Trigger>
                  {#snippet child({ props })}
                    <Button
                      {...props}
                      variant="ghost"
                      size="icon-sm"
                      aria-label={`Actions for ${savedWord}`}
                    >
                      <EllipsisVertical />
                    </Button>
                  {/snippet}
                </DropdownMenu.Trigger>
                <DropdownMenu.Portal>
                  <DropdownMenu.Content
                    align="end"
                    sideOffset={4}
                    onCloseAutoFocus={(event) => {
                      if (editing || pendingRemoval) event.preventDefault();
                    }}
                    class="z-50 min-w-36 rounded-md border bg-popover p-1 text-popover-foreground shadow-md outline-none"
                  >
                    <DropdownMenu.Item
                      onSelect={() => startEdit(entry)}
                      class="flex cursor-pointer items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-none data-highlighted:bg-accent data-highlighted:text-accent-foreground"
                    >
                      <Pencil class="size-4" /> Edit
                    </DropdownMenu.Item>
                    <DropdownMenu.Item
                      onSelect={() => {
                        removeError = "";
                        pendingRemoval = entry;
                      }}
                      class="flex cursor-pointer items-center gap-2 rounded-sm px-2 py-1.5 text-sm text-destructive outline-none data-highlighted:bg-destructive/10"
                    >
                      <Trash2 class="size-4" /> Remove
                    </DropdownMenu.Item>
                  </DropdownMenu.Content>
                </DropdownMenu.Portal>
              </DropdownMenu.Root>
            </div>

            {#if entry.definition?.text}
              <p class="mt-1 text-sm wrap-anywhere whitespace-pre-wrap">{entry.definition.text}</p>
              {#if entry.definition.sourceUrl}
                <p class="mt-1 text-xs text-muted-foreground">
                  <a
                    class="underline"
                    href={entry.definition.sourceUrl}
                    target="_blank"
                    rel="noreferrer"
                  >
                    {entry.definition.custom ? "Adapted from Wiktionary" : "Wiktionary contributors"}
                  </a>
                  ·
                  <a class="underline" href={dictionaryLicense} target="_blank" rel="noreferrer">
                    CC BY-SA 4.0
                  </a>
                </p>
              {/if}
            {/if}

            {#if entry.definition?.note}
              <p class="mt-2 text-sm wrap-anywhere whitespace-pre-wrap text-muted-foreground">
                {entry.definition.note}
              </p>
            {/if}
            {#if entry.tags.length}
              <ul aria-label="Tags" class="mt-2 flex flex-wrap gap-1.5">
                {#each entry.tags as tag (tag)}
                  <li class="max-w-full rounded-md bg-muted px-2 py-0.5 text-xs wrap-anywhere">
                    {tag}
                  </li>
                {/each}
              </ul>
            {/if}
          </li>
        {/each}
      </ul>
    {:else}
      <p class="text-sm text-muted-foreground" role="status">No saved words match your search.</p>
    {/if}
  {/if}
</div>

<Sheet.Root
  open={!!editing}
  onOpenChange={(open) => {
    if (!open && !saving) editing = undefined;
  }}
>
  <Sheet.Content showCloseButton={!saving}>
    <Sheet.Header>
      <Sheet.Title>Edit “{editing?.normalizedForm ?? editing?.word}”</Sheet.Title>
      <Sheet.Description>Update this entry in your saved vocabulary.</Sheet.Description>
    </Sheet.Header>
    <form class="grid gap-4 px-4 pb-4" onsubmit={saveEdit}>
      <label class="grid gap-1.5 text-sm font-medium">
        Saved word
        <Input bind:value={normalizedForm} required maxlength={100} disabled={saving} lang="ko" />
      </label>
      <label class="grid gap-1.5 text-sm font-medium">
        Meaning
        <textarea
          bind:value={meaning}
          rows="3"
          maxlength="8000"
          disabled={saving}
          class="resize-y rounded-md border border-input bg-transparent px-3 py-2 font-normal focus-visible:outline-2 focus-visible:outline-ring"
        ></textarea>
      </label>
      <label class="grid gap-1.5 text-sm font-medium">
        Tags
        <Input bind:value={tags} maxlength={1100} disabled={saving} />
        <span class="text-xs font-normal text-muted-foreground">Separate tags with commas.</span>
      </label>
      <label class="grid gap-1.5 text-sm font-medium">
        Note
        <textarea
          bind:value={note}
          rows="2"
          maxlength="4000"
          disabled={saving}
          class="resize-y rounded-md border border-input bg-transparent px-3 py-2 font-normal focus-visible:outline-2 focus-visible:outline-ring"
        ></textarea>
      </label>
      {#if editError}
        <p class="text-sm text-destructive" role="alert">Could not save changes. {editError}</p>
      {/if}
      <div class="flex gap-2">
        <Button type="button" variant="outline" disabled={saving} onclick={() => (editing = undefined)}>
          Cancel
        </Button>
        <Button type="submit" disabled={saving || !normalizedForm.trim()}
          >{saving ? "Saving…" : "Save changes"}</Button
        >
      </div>
    </form>
  </Sheet.Content>
</Sheet.Root>

<Sheet.Root
  open={!!pendingRemoval}
  onOpenChange={(open) => {
    if (!open && !removing) pendingRemoval = undefined;
  }}
>
  <Sheet.Content>
    <Sheet.Header>
      <Sheet.Title>Remove “{pendingRemoval?.normalizedForm ?? pendingRemoval?.word}”?</Sheet.Title>
      <Sheet.Description>This removes the entry from your saved vocabulary.</Sheet.Description>
    </Sheet.Header>
    <div class="space-y-3 px-4 pb-4">
      {#if removeError}
        <p class="text-sm text-destructive" role="alert">Could not remove the word. {removeError}</p>
      {/if}
      <div class="flex gap-2">
        <Button variant="outline" disabled={removing} onclick={() => (pendingRemoval = undefined)}>
          Cancel
        </Button>
        <Button variant="destructive" disabled={removing} onclick={confirmRemoval}>
          {removing ? "Removing…" : "Remove word"}
        </Button>
      </div>
    </div>
  </Sheet.Content>
</Sheet.Root>
