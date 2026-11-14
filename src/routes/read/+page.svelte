<script lang="ts">
  import { page } from "$app/state";
  import { resolve } from "$app/paths";
  import { isTauri } from "@tauri-apps/api/core";
  import { ArrowLeft } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import DocumentReader from "$lib/features/reader/DocumentReader.svelte";
  import { listDocuments, readDocument } from "$lib/features/library/documents";
  import { readReadingProgress } from "$lib/features/reader/progress";

  let document = $state<{ id: number; title: string; content: string; position: number }>();
  let loading = $state(true);
  let error = $state("");
  let progressError = $state("");

  $effect(() => {
    const parameter = page.url.searchParams.get("id");
    const id = Number(parameter);
    document = undefined;
    error = "";
    progressError = "";
    loading = false;
    if (!parameter || !/^\d+$/.test(parameter) || !Number.isSafeInteger(id) || id <= 0) {
      error = "Choose a document from your library.";
      return;
    }
    if (!isTauri()) {
      error = "Open Sori in the desktop app to read your local documents.";
      return;
    }
    let cancelled = false;
    loading = true;
    void Promise.all([listDocuments(), readDocument(id), readReadingProgress(id)])
      .then(([items, content, position]) => {
        if (cancelled) return;
        const item = items.find((item) => item.id === id);
        if (!item) throw new Error("Document not found.");
        document = { id, title: item.title, content, position };
      })
      .catch((cause) => {
        if (!cancelled) error = cause instanceof Error ? cause.message : String(cause);
      })
      .finally(() => {
        if (!cancelled) loading = false;
      });
    return () => {
      cancelled = true;
    };
  });
</script>

<svelte:head>
  <title>{document?.title ?? "Read"} · Sori</title>
</svelte:head>

<div class="flex h-dvh min-h-0 flex-col">
  <header class="shrink-0 border-b bg-sidebar">
    <div class="mx-auto flex h-14 max-w-6xl items-center gap-3 px-4 sm:px-6 lg:px-8">
      <Sidebar.Trigger class="md:hidden" />
      <Button href={resolve("/library")} variant="ghost" size="sm"><ArrowLeft /> Library</Button>
      {#if document}<h1 class="min-w-0 truncate text-base font-semibold">{document.title}</h1>{/if}
    </div>
  </header>
  <div class="flex min-h-0 min-w-0 w-full flex-1 flex-col">
    {#if loading}
      <p role="status" class="px-6 py-5 text-sm text-muted-foreground">Loading document…</p>
    {:else if error}
      <p role="alert" class="px-6 py-5 text-sm text-destructive">{error}</p>
    {:else if document}
      {#if progressError}<p role="alert" class="mb-3 px-6 text-sm text-destructive">
          {progressError}
        </p>{/if}
      {#key document.id}
        <DocumentReader {document} reportError={(message) => (progressError = message)} />
      {/key}
    {/if}
  </div>
</div>
