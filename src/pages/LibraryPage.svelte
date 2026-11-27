<script lang="ts">
  import { FileText, Film, Pencil, Plus, Search, Trash2, X } from "@lucide/svelte";
  import { onMount } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import {
    addDocument,
    importDocument,
    loadLibraryState,
    readDocument,
    removeDocument,
    removeVideo as removeVideoEntry,
    updateDocument,
    importVideo,
  } from "$lib/library/commands";
  import { openVideoPicker } from "$lib/video/commands";
  import { platform } from "../platform";

  type LibraryItem = { id: number; title: string; pdf: boolean };

  let documents = $state<LibraryItem[]>([]);
  let videos = $state<{ id: number; title: string }[]>([]);
  let query = $state("");
  let error = $state("");
  let busy = $state(false);
  let importOpen = $state(false);
  let editing = $state<LibraryItem | null>(null);
  let draftTitle = $state("");
  let draftText = $state("");
  let deleting = $state<LibraryItem | null>(null);
  let deletingVideo = $state<{ id: number; title: string } | null>(null);

  const visibleDocuments = $derived(
    documents.filter((item) =>
      item.title.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase()),
    ),
  );
  const visibleVideos = $derived(
    videos.filter((item) => item.title.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase())),
  );

  async function load() {
    const state = await loadLibraryState();
    if (!state.ok) {
      error = state.error;
      return;
    }
    documents = (state.data?.documents ?? []) as LibraryItem[];
    videos = (state.data?.videos ?? []) as { id: number; title: string }[];
    error = state.data?.error ?? "";
  }

  onMount(() => {
    const unsubscribe = platform.onEvent("library-changed", () => void load());
    void load();
    return unsubscribe;
  });

  function report(result: { ok: boolean; error: string }) {
    if (!result.ok) error = result.error;
    return result.ok;
  }

  async function chooseFile() {
    if (busy) return;
    busy = true;
    error = "";
    try {
      const picked = await platform.invoke<string | null>("dialog:openDocument");
      if (!report(picked)) return;
      if (!picked.data) return;
      if (report(await importDocument(picked.data))) {
        await load();
        query = "";
        importOpen = false;
      }
    } finally {
      busy = false;
    }
  }

  function openImport() {
    editing = null;
    draftTitle = "";
    draftText = "";
    error = "";
    importOpen = true;
  }

  async function editDocument(item: LibraryItem) {
    const result = await readDocument(item.id);
    if (!report(result)) return;
    editing = item;
    draftTitle = item.title;
    draftText = result.data?.content ?? "";
    error = "";
    importOpen = true;
  }

  async function saveDraft() {
    if (busy || !draftText.trim()) return;
    busy = true;
    error = "";
    try {
      const result = editing
        ? await updateDocument(editing.id, draftTitle, draftText)
        : await addDocument(draftTitle, draftText);
      if (!report(result)) return;
      await load();
      query = "";
      importOpen = false;
      editing = null;
      draftTitle = "";
      draftText = "";
    } finally {
      busy = false;
    }
  }

  function openDocument(item: LibraryItem) {
    location.hash = `#/reader?id=${item.id}`;
    deleting = null;
  }

  function openVideo(id: number) {
    location.hash = `#/watch?id=${id}`;
  }

  async function confirmDeleteVideo() {
    if (!deletingVideo || busy) return;
    busy = true;
    error = "";
    try {
      if (report(await removeVideoEntry(deletingVideo.id))) {
        await load();
        deletingVideo = null;
      }
    } finally {
      busy = false;
    }
  }

  async function chooseVideo() {
    if (busy) return;
    busy = true;
    error = "";
    try {
      const picked = await openVideoPicker();
      if (!report(picked)) return;
      if (!picked.data) return;
      if (report(await importVideo(picked.data))) {
        await load();
        query = "";
      }
    } finally {
      busy = false;
    }
  }

  async function confirmDelete() {
    if (!deleting || busy) return;
    busy = true;
    error = "";
    try {
      if (report(await removeDocument(deleting.id))) {
        await load();
        deleting = null;
      }
    } finally {
      busy = false;
    }
  }
</script>

<div class="flex flex-col gap-4">
  <div class="flex flex-wrap items-center gap-2">
    <div class="relative w-full max-w-sm">
      <Search class="absolute left-2.5 top-2.5 text-muted-foreground" size={16} />
      <Input
        class="pl-8"
        placeholder="Search your library"
        aria-label="Search your library"
        bind:value={query}
      />
    </div>
    <div class="flex-1"></div>
    <Button variant="outline" onclick={openImport} data-testid="import-text">
      <Plus /> Import text
    </Button>
    <Button variant="outline" onclick={chooseVideo} data-testid="import-video">
      <Film /> Import video
    </Button>
  </div>

  {#if error}
    <p class="text-sm text-destructive" data-testid="library-error" role="alert">{error}</p>
  {/if}

  {#if importOpen}
    <section class="rounded-lg border border-border bg-card p-4" data-testid="import-panel">
      <div class="mb-3 flex items-center justify-between">
        <h2 class="text-base font-semibold">{editing ? "Edit text" : "Import text"}</h2>
        <Button variant="ghost" size="icon-sm" aria-label="Close" onclick={() => (importOpen = false)}>
          <X />
        </Button>
      </div>
      <div class="flex flex-col gap-3">
        <Input placeholder="Title (optional)" aria-label="Title" bind:value={draftTitle} />
        <textarea
          class="min-h-40 w-full rounded-md border border-input bg-transparent p-3 font-[family-name:var(--font-korean)]"
          placeholder="Paste Korean text here"
          aria-label="Text"
          bind:value={draftText}></textarea>
        {#if !editing}
          <Button variant="outline" onclick={chooseFile} disabled={busy} data-testid="choose-file">
            <FileText /> Choose .txt or .pdf
          </Button>
        {/if}
        <Button onclick={saveDraft} disabled={busy || !draftText.trim()} data-testid="save-document">
          {editing ? "Save changes" : "Add to library"}
        </Button>
      </div>
    </section>
  {/if}

  <section>
    <h2 class="mb-2 text-sm font-semibold text-muted-foreground" data-testid="text-count">
      Texts ({documents.length})
    </h2>
    {#if visibleDocuments.length === 0}
      <p class="text-sm text-muted-foreground" data-testid="empty-texts">
        {query ? "No matching texts" : "No texts yet"}
      </p>
    {:else}
      <ul class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3" data-testid="document-list">
        {#each visibleDocuments as item (item.id)}
          <li class="flex items-center gap-2 rounded-lg border border-border bg-card p-3">
            <button
              type="button"
              class="flex-1 truncate text-left"
              data-testid={`open-document-${item.id}`}
              onclick={() => openDocument(item)}
            >
              <FileText size={16} class="mr-2 inline text-dashboard-accent" />
              {item.title}{item.pdf ? " · PDF" : ""}
            </button>
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label={`Edit ${item.title}`}
              onclick={() => editDocument(item)}
            >
              <Pencil />
            </Button>
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label={`Delete ${item.title}`}
              onclick={() => (deleting = item)}
            >
              <Trash2 />
            </Button>
          </li>
        {/each}
      </ul>
    {/if}
  </section>

  {#if visibleVideos.length}
    <section>
      <h2 class="mb-2 text-sm font-semibold text-muted-foreground">Videos</h2>
      <ul class="grid gap-2 sm:grid-cols-2" data-testid="video-list">
        {#each visibleVideos as video (video.id)}
          <li class="flex items-center gap-1 rounded-lg border border-border bg-card p-2">
            <button
              type="button"
              class="flex-1 truncate text-left"
              data-testid={`open-video-${video.id}`}
              onclick={() => openVideo(video.id)}
            >
              <Film size={16} class="mr-2 inline text-dashboard-accent" />
              {video.title}
            </button>
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label={`Remove video ${video.title}`}
              onclick={() => (deletingVideo = { id: video.id, title: video.title })}
            >
              <Trash2 />
            </Button>
          </li>
        {/each}
      </ul>
    </section>
  {/if}

  {#if deleting}
    <div
      class="rounded-lg border border-destructive bg-card p-4"
      role="alertdialog"
      data-testid="delete-confirm"
    >
      <p class="mb-3 text-sm">Delete “{deleting.title}” from your library?</p>
      <div class="flex gap-2">
        <Button variant="outline" onclick={() => (deleting = null)}>Cancel</Button>
        <Button variant="destructive" onclick={confirmDelete} disabled={busy}>Delete</Button>
      </div>
    </div>
  {/if}

  {#if deletingVideo}
    <div
      class="rounded-lg border border-destructive bg-card p-4"
      role="alertdialog"
      data-testid="delete-video-confirm"
    >
      <p class="mb-3 text-sm">
        Remove “{deletingVideo.title}” from your library? The video file stays on disk.
      </p>
      <div class="flex gap-2">
        <Button variant="outline" onclick={() => (deletingVideo = null)}>Cancel</Button>
        <Button variant="destructive" onclick={confirmDeleteVideo} disabled={busy}>Remove</Button>
      </div>
    </div>
  {/if}
</div>
