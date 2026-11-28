<script lang="ts">
  import { FolderOpen, Film, Plus, Search } from "@lucide/svelte";
  import { onMount } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import * as Sheet from "$lib/components/ui/sheet";
  import MediaCard from "$lib/library/MediaCard.svelte";
  import { LibraryModel } from "$lib/library/state.svelte";
  import {
    addDocument,
    importDocument,
    readDocument,
    removeDocument,
    removeVideo,
    updateDocument,
    importVideo,
    type DocumentSummary,
    type VideoSummary,
  } from "$lib/library/commands";
  import { openVideoPicker } from "$lib/video/commands";
  import { normalizeDisplayText } from "$lib/text";
  import { platform } from "../platform";

  const library = new LibraryModel();
  let query = $state("");
  let editorOpen = $state(false);
  let editing = $state<DocumentSummary | null>(null);
  let draftTitle = $state("");
  let draftText = $state("");
  let removal = $state<{ item: DocumentSummary | VideoSummary; video: boolean } | null>(null);
  let removalOpen = $state(false);
  let titleField = $state<HTMLInputElement | null>(null);
  let searchField = $state<HTMLInputElement | null>(null);
  const search = $derived(normalizeDisplayText(query.trim()).toLocaleLowerCase());
  const documents = $derived(
    library.documents.filter((item) =>
      normalizeDisplayText(item.title).toLocaleLowerCase().includes(search),
    ),
  );
  const videos = $derived(
    library.videos.filter((item) =>
      normalizeDisplayText(`${item.displayTitle} ${item.title}`).toLocaleLowerCase().includes(search),
    ),
  );

  onMount(() => {
    void library.load();
    const unsubscribe = platform.onEvent("library-changed", () => void library.load());
    return () => {
      library.dispose();
      unsubscribe();
    };
  });
  function openImport() {
    editing = null;
    draftTitle = "";
    draftText = "";
    library.error = "";
    editorOpen = true;
  }
  async function edit(item: DocumentSummary) {
    const success = await library.run(async () => {
      const reply = await readDocument(item.id);
      if (reply.ok && reply.data) {
        editing = item;
        draftTitle = item.title;
        draftText = reply.data.content;
        editorOpen = true;
      }
      return reply;
    });
    if (!success) searchField?.focus();
  }
  async function save(event: SubmitEvent) {
    event.preventDefault();
    if (!draftText.trim() || (editing && !draftTitle.trim())) return;
    const success = await library.run(() =>
      editing ? updateDocument(editing.id, draftTitle, draftText) : addDocument(draftTitle, draftText),
    );
    if (success) {
      editorOpen = false;
      query = "";
    }
  }
  async function chooseFile() {
    let imported = false;
    const success = await library.run(async () => {
      const picked = await platform.invoke<string | null>("dialog:openDocument");
      if (!picked.ok || !picked.data) return picked;
      const reply = await importDocument(picked.data);
      imported = reply.ok;
      return reply;
    });
    if (success && imported) {
      editorOpen = false;
      query = "";
    }
  }
  async function chooseVideo() {
    const success = await library.run(async () => {
      const picked = await openVideoPicker();
      return picked.ok && picked.data ? importVideo(picked.data) : picked;
    });
    if (success) query = "";
  }
  function requestRemoval(item: DocumentSummary | VideoSummary, video: boolean) {
    library.error = "";
    removal = { item, video };
    removalOpen = true;
  }
  async function confirmRemoval() {
    if (!removal) return;
    const { item, video } = removal;
    if (await library.run(() => (video ? removeVideo(item.id) : removeDocument(item.id))))
      removalOpen = false;
  }
  function restoreFocus(event: Event) {
    event.preventDefault();
    searchField?.focus();
  }
</script>

<div class="library-page">
  <div class="library-toolbar">
    <div class="relative w-full max-w-[440px]">
      <Search class="pointer-events-none absolute left-3 top-3 text-muted-foreground" size={15} />
      <Input
        bind:ref={searchField}
        class="h-[38px] pl-9 text-[13px]"
        placeholder="Search your library"
        aria-label="Search your library"
        bind:value={query}
      />
    </div>
    <div class="flex gap-2">
      <Button variant="outline" disabled={library.busy} onclick={openImport} data-testid="import-text">
        <Plus size={15} />Import text
      </Button>
      <Button
        variant="outline"
        disabled={library.busy}
        onclick={chooseVideo}
        data-testid="import-video"
      >
        <Film size={15} />Import video
      </Button>
    </div>
  </div>
  {#if library.error && !editorOpen && !removalOpen}<p
      class="text-sm text-destructive"
      data-testid="library-error"
      role="alert"
    >
      {library.error} <button class="underline" onclick={() => library.load()}>Retry</button>
    </p>{/if}
  {#if library.loading}<p role="status" class="text-sm text-muted-foreground">
      Loading library…
    </p>{:else}
    {#if !search || documents.length}
      <section aria-labelledby="texts-title">
        <h2 id="texts-title" class="shelf-title" data-testid="text-count">
          Texts <span>{documents.length}</span>
        </h2>
        {#if documents.length}
          <ul class="document-shelf" data-testid="document-list">
            {#each documents as item (item.id)}<li>
                <MediaCard
                  {item}
                  busy={library.busy}
                  onEdit={item.pdf ? undefined : () => edit(item)}
                  onRemove={() => requestRemoval(item, false)}
                />
              </li>{/each}
          </ul>
        {:else}<p class="empty-shelf" data-testid="empty-texts">No texts yet</p>{/if}
      </section>
    {/if}
    {#if !search || videos.length}
      <section aria-labelledby="videos-title">
        <h2 id="videos-title" class="shelf-title">Videos <span>{videos.length}</span></h2>
        {#if videos.length}
          <ul class="video-shelf" data-testid="video-list">
            {#each videos as item (item.id)}<li>
                <MediaCard
                  {item}
                  video
                  busy={library.busy}
                  onRemove={() => requestRemoval(item, true)}
                />
              </li>{/each}
          </ul>
        {:else}<p class="empty-shelf">No videos yet</p>{/if}
      </section>
    {/if}
    {#if search && !documents.length && !videos.length}<p role="status" class="empty-shelf">
        No matching items. Try another title.
      </p>{/if}
    {#if !search && !library.documents.length && !library.videos.length && !library.error}<p
        class="text-sm text-muted-foreground"
      >
        Import a video, a .txt or .pdf file, or paste Korean text to get started.
      </p>{/if}
  {/if}
</div>

<Sheet.Root
  bind:open={editorOpen}
  onOpenChange={(open) => {
    if (!open) library.error = "";
  }}
>
  <Sheet.Content
    onOpenAutoFocus={(event) => {
      event.preventDefault();
      titleField?.focus();
    }}
    onCloseAutoFocus={restoreFocus}
    showCloseButton={false}
    overlayProps={{ style: "backdrop-filter: none;" }}
    class="h-[520px] max-h-[calc(var(--app-height)-3rem)] w-[calc(100%-3rem)] max-w-[560px] gap-0 rounded-[20px] border-0 bg-card p-5 shadow-none"
    data-testid="import-panel"
  >
    <Sheet.Header class="mb-3 shrink-0 gap-0 p-0">
      <Sheet.Title class="text-lg font-semibold">
        {editing ? "Edit document" : "Import text or PDF"}
      </Sheet.Title>
      <Sheet.Description class="sr-only">
        {editing
          ? "Update the title or text. Changing the text resets its reading progress."
          : "Choose a text or PDF file, or paste Korean text to import."}
      </Sheet.Description>
    </Sheet.Header>
    <form class="flex min-h-0 flex-1 flex-col gap-3" onsubmit={save}>
      {#if !editing}
        <Button
          type="button"
          variant="outline"
          class="h-[38px] shrink-0 self-start bg-transparent px-3 text-[13px] shadow-none"
          onclick={chooseFile}
          disabled={library.busy}
          data-testid="choose-file"
        >
          <FolderOpen size={16} />Choose a text or PDF file
        </Button>
      {/if}
      <label class="flex shrink-0 flex-col gap-1.5 text-sm font-medium">
        <span>Title</span>
        <Input
          bind:ref={titleField}
          aria-label="Title"
          placeholder="Title"
          class="h-[38px] rounded-xl font-normal"
          bind:value={draftTitle}
          disabled={library.busy}
        />
      </label>
      <label class="flex min-h-0 flex-1 flex-col gap-1.5 text-sm font-medium">
        <span>Text</span>
        <textarea
          aria-label="Text"
          class="min-h-16 flex-1 resize-none rounded-xl border border-input bg-transparent p-3 font-[family-name:var(--font-korean)] text-[15px] font-normal outline-none placeholder:text-muted-foreground"
          placeholder="Paste or type Korean text"
          bind:value={draftText}
          disabled={library.busy}></textarea>
      </label>
      {#if library.error}<p role="alert" class="shrink-0 text-sm text-destructive">
          {library.error}
        </p>{/if}
      <div class="mt-0.5 flex shrink-0 justify-end gap-2">
        <Button
          type="button"
          variant="outline"
          class="h-[38px] bg-transparent px-4 text-[13px] shadow-none"
          disabled={library.busy}
          onclick={() => (editorOpen = false)}
        >
          Cancel
        </Button>
        <Button
          type="submit"
          variant="ghost"
          class="h-[38px] bg-accent-soft px-4 text-[13px] text-dashboard-accent hover:bg-accent-soft disabled:bg-transparent disabled:text-muted-foreground disabled:opacity-100"
          disabled={library.busy || !draftText.trim() || (!!editing && !draftTitle.trim())}
          data-testid="save-document"
        >
          {library.busy ? "Saving…" : editing ? "Save changes" : "Import text"}
        </Button>
      </div>
    </form>
  </Sheet.Content>
</Sheet.Root>

<Sheet.Root
  bind:open={removalOpen}
  onOpenChange={(open) => {
    if (!open) library.error = "";
  }}
>
  <Sheet.Content
    onCloseAutoFocus={restoreFocus}
    data-testid={removal?.video ? "delete-video-confirm" : "delete-confirm"}
  >
    <Sheet.Header>
      <Sheet.Title>{removal?.video ? "Remove video" : "Delete text"}</Sheet.Title><Sheet.Description>
        {removal?.video
          ? `Remove “${normalizeDisplayText((removal.item as VideoSummary).displayTitle || removal.item.title)}” from your library? The video file stays on disk.`
          : `Delete “${normalizeDisplayText(removal?.item.title ?? "")}” from your library?`}
      </Sheet.Description>
    </Sheet.Header>
    <div class="space-y-4 px-5 pb-5">
      {#if library.error}<p role="alert" class="text-sm text-destructive">{library.error}</p>{/if}
      <div class="flex justify-end gap-2">
        <Button variant="outline" disabled={library.busy} onclick={() => (removalOpen = false)}>
          Cancel
        </Button><Button variant="destructive" disabled={library.busy} onclick={confirmRemoval}>
          {removal?.video ? "Remove" : "Delete"}
        </Button>
      </div>
    </div>
  </Sheet.Content>
</Sheet.Root>

<style>
  .library-page {
    display: flex;
    flex-direction: column;
    gap: 26px;
  }
  .library-toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 12px;
    margin-bottom: -10px;
  }
  .shelf-title {
    display: flex;
    align-items: center;
    gap: 9px;
    font-size: 18px;
    line-height: 1.2;
    font-weight: 600;
    margin-bottom: 10px;
  }
  .shelf-title span {
    font-size: 13px;
    font-weight: 400;
    color: var(--muted-foreground);
  }
  .document-shelf,
  .video-shelf {
    display: grid;
    gap: 26px 20px;
    grid-template-columns: repeat(auto-fill, minmax(min(100%, 180px), 220px));
    list-style: none;
    padding: 0;
  }
  .video-shelf {
    grid-template-columns: repeat(auto-fill, minmax(min(100%, 260px), 340px));
  }
  .empty-shelf {
    padding: 16px 0;
    font-size: 14px;
    color: var(--muted-foreground);
  }
  @media (max-width: 600px) {
    .document-shelf {
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 20px 14px;
    }
    .video-shelf {
      grid-template-columns: minmax(0, 1fr);
    }
  }
</style>
