<script lang="ts">
  import { BookOpen, Library, Plus, Search, X } from "@lucide/svelte";
  import { onMount, tick } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import * as Sheet from "$lib/components/ui/sheet";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import { isTauri } from "@tauri-apps/api/core";
  import {
    importDocument,
    listDocuments,
    readDocument,
    type LibraryItem,
  } from "$lib/features/library/documents";

  let desktop = $state(false);
  let documents = $state<LibraryItem[]>([]);
  let fileInput = $state<HTMLInputElement>();
  let busy = $state(false);
  let error = $state("");
  let documentOpen = $state(false);
  let selected = $state<{ title: string; content: string }>();
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

    void runLibraryAction(async () => {
      await importDocument(file);
      documents = await listDocuments();
      query = "";
    });
  }

  function openDocument(item: LibraryItem) {
    void runLibraryAction(async () => {
      selected = { title: item.title, content: await readDocument(item.id) };
      documentOpen = true;
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

<header class="border-b bg-sidebar">
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
        onclick={() => fileInput?.click()}
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
        <li>
          <Button
            variant="outline"
            class="h-auto w-full justify-start gap-3 p-4 text-left whitespace-normal"
            disabled={busy}
            onclick={() => openDocument(item)}
          >
            <BookOpen />
            {item.title}
          </Button>
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
              ? "Import a text file to start reading."
              : "Open Sori in the desktop app to import files."}
          </p>
        {/if}
      </div>
    </section>
  {/if}
</div>

<Sheet.Root bind:open={documentOpen}>
  <Sheet.Content class="w-full overflow-y-auto sm:max-w-2xl">
    {#if selected}
      <Sheet.Header class="pr-14">
        <Sheet.Title>{selected.title}</Sheet.Title>
        <Sheet.Description class="sr-only">Imported text document</Sheet.Description>
      </Sheet.Header>
      <p lang="ko" class="px-6 pb-8 text-base leading-8 wrap-break-word whitespace-pre-wrap">
        {selected.content}
      </p>
    {/if}
  </Sheet.Content>
</Sheet.Root>
