<script lang="ts">
  import { onMount } from "svelte";
  import { ArrowLeft, ArrowRight, Minus, Plus } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import {
    getDocument,
    GlobalWorkerOptions,
    TextLayer,
    type PDFDocumentProxy,
    type RenderTask,
  } from "pdfjs-dist";
  import workerSrc from "pdfjs-dist/build/pdf.worker.min.mjs?url";
  import "pdfjs-dist/web/pdf_viewer.css";
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
  let pdf: PDFDocumentProxy | null = null;
  let pageCount = $state(0),
    currentPage = $state(1);
  let mode = $state<"book" | "scroll">("book");
  let zoom = $state(1),
    error = $state(""),
    loading = $state(true);
  let container: HTMLDivElement;
  let generation = 0,
    disposed = false,
    rendering = false;
  let renderTask: RenderTask | undefined;
  let resizeTimer: ReturnType<typeof setTimeout>;
  let saveTimer: ReturnType<typeof setTimeout>;
  let lastPosition = 0;
  function save() {
    clearTimeout(saveTimer);
    if (!pageCount) return;
    const value = pageCount > 1 ? (currentPage - 1) / (pageCount - 1) : 0;
    if (value !== lastPosition) {
      lastPosition = value;
      onProgress(value);
    }
  }
  onMount(() => {
    lastPosition = position;
    const task = getDocument({ url: `sori-pdf://pdf/${documentId}.pdf` });
    void task.promise
      .then(async (loaded) => {
        if (disposed) return;
        pdf = loaded;
        pageCount = loaded.numPages;
        currentPage = Math.round(Math.max(0, Math.min(1, position)) * Math.max(0, pageCount - 1)) + 1;
        await renderPages();
      })
      .catch((cause) => {
        if (!disposed) {
          error = String(cause);
          loading = false;
        }
      });
    let oldWidth = 0,
      oldHeight = 0;
    const observer = new ResizeObserver(([entry]) => {
      const { width, height } = entry.contentRect;
      if (Math.abs(width - oldWidth) < 1 && Math.abs(height - oldHeight) < 1) return;
      oldWidth = width;
      oldHeight = height;
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => void renderPages(), 100);
    });
    observer.observe(container);
    window.addEventListener("pagehide", save);
    return () => {
      save();
      disposed = true;
      generation++;
      renderTask?.cancel();
      observer.disconnect();
      clearTimeout(resizeTimer);
      clearTimeout(saveTimer);
      window.removeEventListener("pagehide", save);
      void task.destroy();
    };
  });
  async function renderPages() {
    if (!pdf || !container || disposed) return;
    const token = ++generation;
    renderTask?.cancel();
    rendering = true;
    loading = true;
    error = "";
    container.replaceChildren();
    const anchor = currentPage;
    try {
      const numbers = mode === "book" ? [anchor] : Array.from({ length: pageCount }, (_, i) => i + 1);
      for (const number of numbers) {
        const page = await pdf.getPage(number);
        if (disposed || token !== generation) return;
        const base = page.getViewport({ scale: 1 });
        const availableWidth = Math.max(100, container.clientWidth - 48);
        const scale =
          mode === "book"
            ? Math.min(
                availableWidth / base.width,
                Math.max(100, container.clientHeight - 48) / base.height,
              ) * zoom
            : (Math.min(920, availableWidth) / base.width) * zoom;
        const viewport = page.getViewport({ scale });
        const host = document.createElement("div");
        host.dataset.page = String(number);
        host.style.cssText = `position:relative;flex-shrink:0;background:white;width:${viewport.width}px;height:${viewport.height}px;`;
        container.append(host);
        const canvas = document.createElement("canvas");
        const ratio = window.devicePixelRatio || 1;
        canvas.width = Math.ceil(viewport.width * ratio);
        canvas.height = Math.ceil(viewport.height * ratio);
        canvas.style.cssText = `display:block;width:${viewport.width}px;height:${viewport.height}px`;
        host.append(canvas);
        renderTask = page.render({ canvas, viewport, transform: [ratio, 0, 0, ratio, 0, 0] });
        await renderTask.promise;
        if (disposed || token !== generation) return;
        const layer = document.createElement("div");
        layer.className = "textLayer";
        host.append(layer);
        const content = await page.getTextContent();
        if (disposed || token !== generation) return;
        await new TextLayer({ textContentSource: content, container: layer, viewport }).render();
        if (disposed || token !== generation) return;
        layer.addEventListener("click", (event) => {
          const target = event.target as HTMLElement;
          if (target === layer) {
            if (mode === "book")
              goTo(
                currentPage +
                  (event.clientX < host.getBoundingClientRect().x + host.clientWidth / 2 ? -1 : 1),
              );
            return;
          }
          const caret = document.caretPositionFromPoint(event.clientX, event.clientY);
          const text = target.textContent ?? "";
          const offset = caret?.offsetNode.parentElement === target ? caret.offset : 0;
          const start = text.slice(0, offset).search(/\S+$/u);
          const end = text.slice(offset).search(/\s/u);
          const word = text
            .slice(start < 0 ? offset : start, end < 0 ? text.length : offset + end)
            .trim();
          if (word) onWord(word);
        });
      }
      if (mode === "scroll") {
        const host = container.querySelector<HTMLElement>(`[data-page="${anchor}"]`);
        if (host) container.scrollTop = host.offsetTop - 18;
      } else container.scrollTop = 0;
    } catch (cause) {
      if (!disposed && token === generation) error = String(cause);
    } finally {
      if (!disposed && token === generation) {
        rendering = false;
        loading = false;
      }
    }
  }
  function goTo(page: number) {
    const next = Math.max(1, Math.min(pageCount, page));
    if (!pageCount || next === currentPage) return;
    currentPage = next;
    save();
    void renderPages();
  }
  function setMode(next: "book" | "scroll") {
    save();
    mode = next;
    void renderPages();
  }
  function setZoom(value: number) {
    zoom = Math.max(0.5, Math.min(2, Math.round(value * 10) / 10));
    void renderPages();
  }
  function onScroll() {
    if (mode !== "scroll" || rendering) return;
    const top = container.getBoundingClientRect().top;
    const hosts = [...container.querySelectorAll<HTMLElement>("[data-page]")];
    const visible = hosts.find((host) => host.getBoundingClientRect().bottom > top + 40);
    if (visible) currentPage = Number(visible.dataset.page);
    clearTimeout(saveTimer);
    saveTimer = setTimeout(save, 500);
  }
  function onKey(event: KeyboardEvent) {
    if (
      mode !== "book" ||
      event.defaultPrevented ||
      (event.target instanceof HTMLElement &&
        event.target.closest("button,input,textarea,select,[data-testid=analysis-panel]"))
    )
      return;
    if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      event.preventDefault();
      goTo(currentPage + (event.key === "ArrowLeft" ? -1 : 1));
    }
  }
</script>

<svelte:window onkeydown={onKey} />
<div class="pdf-workspace">
  <div class="toolbar">
    {#if mode === "book"}<Button
        variant="ghost"
        size="icon-sm"
        aria-label="Previous page"
        disabled={currentPage <= 1}
        onclick={() => goTo(currentPage - 1)}
      >
        <ArrowLeft size={15} />
      </Button>{/if}
    <span class="text-xs text-muted-foreground" data-testid="pdf-page">
      Page {currentPage} / {pageCount}
    </span>
    {#if mode === "book"}<Button
        variant="ghost"
        size="icon-sm"
        aria-label="Next page"
        disabled={currentPage >= pageCount}
        onclick={() => goTo(currentPage + 1)}
      >
        <ArrowRight size={15} />
      </Button>{/if}
    <div class="ml-auto flex items-center gap-2">
      <Button
        variant="ghost"
        size="icon-sm"
        aria-label="Zoom out"
        disabled={zoom <= 0.5}
        onclick={() => setZoom(zoom - 0.1)}
      >
        <Minus size={13} />
      </Button>
      <button
        class="text-xs text-muted-foreground"
        aria-label="Reset PDF zoom"
        onclick={() => setZoom(1)}
      >
        {Math.round(zoom * 100)}%
      </button>
      <Button
        variant="ghost"
        size="icon-sm"
        aria-label="Zoom in"
        disabled={zoom >= 2}
        onclick={() => setZoom(zoom + 0.1)}
      >
        <Plus size={13} />
      </Button>
      <Button variant="outline" size="sm" onclick={() => setMode(mode === "book" ? "scroll" : "book")}>
        {mode === "book" ? "Scroll" : "Book"}
      </Button>
    </div>
  </div>
  {#if error}<p class="px-5 text-sm text-destructive" role="alert" data-testid="pdf-error">
      {error}
    </p>{/if}
  {#if loading}<span class="sr-only" role="status">Loading PDF…</span>{/if}
  <div bind:this={container} data-testid="pdf-container" class="pdf-pages" onscroll={onScroll}></div>
</div>

<style>
  .pdf-workspace {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
  }
  .toolbar {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 14px;
    flex-shrink: 0;
  }
  .pdf-pages {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 20px;
    flex: 1;
    min-height: 0;
    overflow: auto;
    padding: 18px 24px 24px;
  }
</style>
