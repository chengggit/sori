<script lang="ts">
  import { BookOpen, Library, Plus, Search, X, Pencil, Trash2, EllipsisVertical } from "@lucide/svelte";
  import { DropdownMenu } from "bits-ui";
  import { onMount, tick } from "svelte";
  import { resolve } from "$app/paths";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import * as Sheet from "$lib/components/ui/sheet";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import { isTauri } from "@tauri-apps/api/core";
  import {
    importDocument,
    listDocuments,
    readDocument,
    updateDocument,
    deleteDocument,
    type LibraryItem,
  } from "$lib/features/library/documents";

  let desktop = $state(false);
  let documents = $state<LibraryItem[]>([]);
  let fileInput = $state<HTMLInputElement>();
  let busy = $state(false);
  let error = $state("");
  let importOpen = $state(false);
  let pastedTitle = $state("");
  let pastedText = $state("");
  let importError = $state("");
  let editing = $state<LibraryItem>();
  let editTitle = $state("");
  let editText = $state("");
  let editError = $state("");
  let deleting = $state<LibraryItem>();
  let deleteError = $state("");

  function editDocument(item: LibraryItem) {
    void runLibraryAction(async () => {
      editText = await readDocument(item.id);
      editTitle = item.title;
      editError = "";
      editing = item;
    });
  }

  async function saveEdit() {
    if (!editing || busy) return;
    busy = true;
    editError = "";
    try {
      await updateDocument(editing.id, editTitle, editText);
      documents = await listDocuments();
      editing = undefined;
    } catch (cause) {
      editError = String(cause);
    } finally {
      busy = false;
    }
  }

  async function confirmDelete() {
    if (!deleting || busy) return;
    busy = true;
    deleteError = "";
    try {
      await deleteDocument(deleting.id);
      documents = await listDocuments();
      deleting = undefined;
    } catch (cause) {
      deleteError = String(cause);
    } finally {
      busy = false;
    }
  }
  let visibleDocuments = $derived(
    documents.filter((item) =>
      item.title.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase()),
    ),
  );

  let searchOpen = $state(false);
  let query = $state("");
  let searchInput = $state<HTMLInputElement | null>(null);
  onMount(() => {
    desktop = isTauri();
    if (desktop)
      void runLibraryAction(async () => {
        documents = await listDocuments();
      });
  });

  async function runLibraryAction(action: () => Promise<void>) {
    if (busy) return;
    busy = true;
    error = "";
    try {
      await action();
    } catch (cause) {
      error = cause instanceof Error ? cause.message : String(cause);
    } finally {
      busy = false;
    }
  }

  function importFile(event: Event & { currentTarget: HTMLInputElement }) {
    const file = event.currentTarget.files?.[0];
    event.currentTarget.value = "";
    if (!file) return;

    importOpen = false;
    void runLibraryAction(async () => {
      await importDocument(file);
      documents = await listDocuments();
      query = "";
    });
  }

  function importPastedText() {
    if (!pastedText.trim()) return;

    void runLibraryAction(async () => {
      importError = "";
      try {
        const title = pastedTitle.trim() || "Pasted text";
        await importDocument(new File([pastedText], title + ".txt"));
      } catch (cause) {
        importError = cause instanceof Error ? cause.message : String(cause);
        return;
      }

      pastedTitle = "";
      pastedText = "";
      importOpen = false;
      documents = await listDocuments();
      query = "";
    });
  }

  async function toggleSearch() {
    searchOpen = !searchOpen;
    if (searchOpen) {
      await tick();
      searchInput?.focus();
    } else {
      query = "";
    }
  }
</script>

<svelte:head>
  <title>My Library · Sori</title>
  <meta name="description" content="Your Korean reading and watching library." />
</svelte:head>

<header class="border-b">
  <div class="mx-auto flex h-14 max-w-6xl items-center justify-between px-4 sm:px-6 lg:px-8">
    <div class="flex items-center gap-2">
      <Sidebar.Trigger class="md:hidden" />
      <h1 class="text-base font-semibold">My Library</h1>
      <span class="text-sm text-muted-foreground"
        >{documents.length} {documents.length === 1 ? "item" : "items"}</span
      >
    </div>
    <div class="flex items-center gap-1.5">
      <Button
        variant="ghost"
        size="icon-sm"
        aria-label={searchOpen ? "Close search" : "Search library"}
        aria-expanded={searchOpen}
        onclick={toggleSearch}
      >
        {#if searchOpen}<X />{:else}<Search />{/if}
      </Button>
      <Button
        variant="secondary"
        size="sm"
        disabled={!desktop || busy}
        onclick={() => (importOpen = true)}
      >
        <Plus />
        Import
      </Button>
    </div>
  </div>
</header>

<div class="mx-auto max-w-6xl px-4 py-5 sm:px-6 lg:px-8">
  {#if searchOpen}
    <div class="relative mb-4">
      <Search class="pointer-events-none absolute top-2.5 left-3 size-4 text-muted-foreground" />
      <Input
        bind:ref={searchInput}
        bind:value={query}
        aria-label="Search by title"
        placeholder="Search by title"
        class="pl-9"
      />
    </div>
  {/if}

  <input type="file" accept=".txt" bind:this={fileInput} onchange={importFile} hidden />
  {#if error}
    <p class="mb-4 text-sm text-destructive" role="alert">{error}</p>
  {/if}

  {#if visibleDocuments.length}
    <ul class="grid gap-2">
      {#each visibleDocuments as item (item.id)}
        <li class="flex items-center gap-2">
          <Button
            variant="outline"
            class="h-auto min-w-0 flex-1 justify-start gap-3 p-4 text-left whitespace-normal"
            href={resolve("/read") + "?id=" + item.id}
          >
            <BookOpen />
            {item.title}
          </Button>
          <DropdownMenu.Root>
            <DropdownMenu.Trigger disabled={busy}>
              {#snippet child({ props })}
                <Button
                  {...props}
                  variant="ghost"
                  size="icon-sm"
                  aria-label={`Actions for ${item.title}`}><EllipsisVertical /></Button
                >
              {/snippet}
            </DropdownMenu.Trigger>
            <DropdownMenu.Portal>
              <DropdownMenu.Content
                align="end"
                sideOffset={4}
                onCloseAutoFocus={(event) => {
                  if (deleting || editing) event.preventDefault();
                }}
                class="z-50 min-w-36 rounded-md border bg-popover p-1 text-popover-foreground shadow-md outline-none"
              >
                <DropdownMenu.Item
                  disabled={busy}
                  onSelect={() => editDocument(item)}
                  class="flex cursor-pointer items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-none data-highlighted:bg-accent data-highlighted:text-accent-foreground data-disabled:opacity-50"
                >
                  <Pencil class="size-4" /> Edit
                </DropdownMenu.Item>
                <DropdownMenu.Item
                  disabled={busy}
                  onSelect={() => {
                    deleting = item;
                    deleteError = "";
                  }}
                  class="flex cursor-pointer items-center gap-2 rounded-sm px-2 py-1.5 text-sm text-destructive outline-none data-highlighted:bg-destructive/10 data-disabled:opacity-50"
                >
                  <Trash2 class="size-4" /> Delete
                </DropdownMenu.Item>
              </DropdownMenu.Content>
            </DropdownMenu.Portal>
          </DropdownMenu.Root>
        </li>
      {/each}
    </ul>
  {:else}
    <section
      class="grid min-h-72 place-items-center rounded-xl border border-dashed bg-card px-5 py-12 text-center"
    >
      <div>
        <Library class="mx-auto mb-4 size-6 text-muted-foreground" />
        <h2 class="font-medium">
          {busy ? "Loading library…" : query.trim() ? "No matching documents" : "Your library is empty"}
        </h2>
        {#if !busy && !query.trim()}
          <p class="mt-1 text-sm text-muted-foreground">
            {desktop
              ? "Paste text or import a .txt file to start reading."
              : "Open Sori in the desktop app to import text."}
          </p>
        {/if}
      </div>
    </section>
  {/if}
</div>

<Sheet.Root bind:open={importOpen}>
  <Sheet.Content>
    <Sheet.Header>
      <Sheet.Title>Import text</Sheet.Title>
      <Sheet.Description>Paste text or choose a .txt file to add to your library.</Sheet.Description>
    </Sheet.Header>
    <form
      class="space-y-4 px-4 pb-4"
      onsubmit={(event) => {
        event.preventDefault();
        importPastedText();
      }}
    >
      <div class="space-y-1.5">
        <label for="import-title" class="text-sm font-medium">Title (optional)</label>
        <Input id="import-title" bind:value={pastedTitle} disabled={busy} placeholder="Pasted text" />
      </div>
      <div class="space-y-1.5">
        <label for="import-text" class="text-sm font-medium">Text</label>
        <textarea
          id="import-text"
          bind:value={pastedText}
          disabled={busy}
          placeholder="Paste your text here"
          class="min-h-48 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-ring"
        ></textarea>
      </div>
      {#if importError}<p class="text-sm text-destructive" role="alert">{importError}</p>{/if}
      <div class="flex flex-wrap gap-2">
        <Button type="submit" disabled={busy || !pastedText.trim()}>Import text</Button>
        <Button type="button" variant="outline" disabled={busy} onclick={() => fileInput?.click()}>
          Choose .txt file
        </Button>
      </div>
    </form>
  </Sheet.Content>
</Sheet.Root>

<Sheet.Root
  open={!!editing}
  onOpenChange={(open) => {
    if (!open && !busy) editing = undefined;
  }}
>
  <Sheet.Content>
    <Sheet.Header
      ><Sheet.Title>Edit text</Sheet.Title><Sheet.Description
        >Changing the text resets its reading position. Saved vocabulary keeps its original context.</Sheet.Description
      ></Sheet.Header
    >
    <form
      class="space-y-4 px-4 pb-4"
      onsubmit={(event) => {
        event.preventDefault();
        void saveEdit();
      }}
    >
      <div class="space-y-1.5">
        <label for="edit-title" class="text-sm font-medium">Title</label><Input
          id="edit-title"
          bind:value={editTitle}
          disabled={busy}
        />
      </div>
      <div class="space-y-1.5">
        <label for="edit-text" class="text-sm font-medium">Text</label><textarea
          id="edit-text"
          bind:value={editText}
          disabled={busy}
          class="min-h-64 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-ring"
        ></textarea>
      </div>
      {#if editError}<p role="alert" class="text-sm text-destructive">{editError}</p>{/if}
      <Button type="submit" disabled={busy || !editTitle.trim() || !editText.trim()}
        >Save changes</Button
      >
    </form>
  </Sheet.Content>
</Sheet.Root>

<Sheet.Root
  open={!!deleting}
  onOpenChange={(open) => {
    if (!open && !busy) deleting = undefined;
  }}
>
  <Sheet.Content>
    <Sheet.Header
      ><Sheet.Title>Delete “{deleting?.title}”?</Sheet.Title><Sheet.Description
        >This removes the imported document and its reading progress. Saved vocabulary and its original
        context are retained.</Sheet.Description
      ></Sheet.Header
    >
    <div class="space-y-3 px-4 pb-4">
      {#if deleteError}<p role="alert" class="text-sm text-destructive">{deleteError}</p>{/if}
      <div class="flex gap-2">
        <Button variant="outline" disabled={busy} onclick={() => (deleting = undefined)}>Cancel</Button
        ><Button variant="destructive" disabled={busy} onclick={confirmDelete}>Delete document</Button>
      </div>
    </div>
  </Sheet.Content>
</Sheet.Root>
