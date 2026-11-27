<script lang="ts">
  import { onDestroy, onMount } from "svelte";
  import { getDocument, GlobalWorkerOptions, TextLayer, type PDFDocumentProxy } from "pdfjs-dist";
  import workerSrc from "pdfjs-dist/build/pdf.worker.min.mjs?url";
  import "pdfjs-dist/web/pdf_viewer.css";
  import { trackReadingProgress } from "$lib/reader/progress";

  GlobalWorkerOptions.workerSrc = workerSrc;

  let {
    documentId,
    position,
    onProgress,
    onWord,
  }: {
    documentId: number;
    position: number;
    onProgress: (position: number) => void;
    onWord: (word: string) => void;
  } = $props();

  let pdf = $state<PDFDocumentProxy | null>(null);
  let pageCount = $state(0);
  let currentPage = $state(1);
  let mode = $state<"book" | "scroll">("book");
  let zoom = $state(1);
  let error = $state("");
  let container = $state<HTMLDivElement>();
  let renderToken = 0;
  let stopTracking: (() => void) | undefined;

  onDestroy(() => stopTracking?.());
  onMount(() => {
    void load();
  });

  async function load() {
    try {
      pdf = await getDocument({ url: `sori-pdf://pdf/${documentId}.pdf` }).promise;
      pageCount = pdf.numPages;
      currentPage = Math.round(Math.max(0, Math.min(1, position)) * Math.max(0, pageCount - 1)) + 1;
      await renderPages();
    } catch (cause) {
      error = cause instanceof Error ? cause.message : String(cause);
    }
  }

  async function renderPages() {
    if (!pdf || !container) return;
    const token = ++renderToken;
    stopTracking?.();
    container.replaceChildren();

    const numbers =
      mode === "book" ? [currentPage] : Array.from({ length: pageCount }, (_, index) => index + 1);
    for (const pageNumber of numbers) {
      const page = await pdf.getPage(pageNumber);
      if (token !== renderToken) return;
      const viewport = page.getViewport({ scale: zoom });
      const host = document.createElement("div");
      host.style.cssText =
        "display:inline-block;margin:0 auto 20px;position:relative;box-shadow:0 1px 6px rgb(0 0 0 / 20%)";
      container.append(host);

      const canvas = document.createElement("canvas");
      canvas.width = Math.ceil(viewport.width);
      canvas.height = Math.ceil(viewport.height);
      canvas.style.width = `${viewport.width}px`;
      canvas.style.height = `${viewport.height}px`;
      host.append(canvas);
      await page.render({ canvas, viewport }).promise;
      if (token !== renderToken) return;

      const layer = document.createElement("div");
      layer.className = "textLayer";
      host.append(layer);
      const textContent = await page.getTextContent();
      const textLayer = new TextLayer({ textContentSource: textContent, container: layer, viewport });
      await textLayer.render();
      if (token !== renderToken) return;
      layer.addEventListener("click", (event) => {
        const word = (event.target as HTMLElement).textContent?.trim();
        if (word) onWord(word);
      });
    }

    if (mode === "scroll") {
      stopTracking = trackReadingProgress(
        container,
        position,
        async (value) => onProgress(value),
        (message) => (error = message),
      );
    }
  }

  function goTo(page: number) {
    if (!pageCount) return;
    const next = Math.max(1, Math.min(pageCount, page));
    if (next === currentPage && mode === "book") return;
    currentPage = next;
    if (mode === "book") onProgress(pageCount > 1 ? (currentPage - 1) / (pageCount - 1) : 0);
    void renderPages();
  }

  function setMode(next: "book" | "scroll") {
    if (mode === next) return;
    mode = next;
    void renderPages();
  }

  function setZoom(value: number) {
    zoom = Math.max(0.5, Math.min(2, value));
    void renderPages();
  }
</script>

<div class="flex flex-col gap-2">
  <div class="flex flex-wrap items-center gap-2">
    <div class="flex rounded-md border border-border" role="group" aria-label="PDF view mode">
      <button
        type="button"
        class="px-3 py-1 text-sm"
        class:bg-accent-soft={mode === "book"}
        onclick={() => setMode("book")}
      >
        Book
      </button>
      <button
        type="button"
        class="px-3 py-1 text-sm"
        class:bg-accent-soft={mode === "scroll"}
        onclick={() => setMode("scroll")}
      >
        Scroll
      </button>
    </div>
    <label class="flex items-center gap-2 text-sm">
      Zoom
      <input
        type="range"
        min="0.5"
        max="2"
        step="0.1"
        value={zoom}
        aria-label="PDF zoom"
        oninput={(event) => setZoom(Number(event.currentTarget.value))}
      />
    </label>
    {#if mode === "book"}
      <span class="ml-auto text-sm text-muted-foreground" data-testid="pdf-page">
        Page {currentPage} / {pageCount}
      </span>
    {/if}
  </div>

  {#if error}
    <p class="text-sm text-destructive" role="alert" data-testid="pdf-error">{error}</p>
  {/if}

  <div class="relative">
    <div
      bind:this={container}
      data-testid="pdf-container"
      class="h-[62vh] overflow-auto rounded-lg border border-border bg-card p-4"
    ></div>
    {#if mode === "book" && pageCount > 1}
      <button
        type="button"
        class="absolute left-2 top-1/2 -translate-y-1/2 rounded-full border border-border bg-card px-3 py-2"
        aria-label="Previous page"
        onclick={() => goTo(currentPage - 1)}
      >
        ‹
      </button>
      <button
        type="button"
        class="absolute right-2 top-1/2 -translate-y-1/2 rounded-full border border-border bg-card px-3 py-2"
        aria-label="Next page"
        onclick={() => goTo(currentPage + 1)}
      >
        ›
      </button>
    {/if}
  </div>
</div>
