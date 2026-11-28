<script lang="ts">
  import { tokenizeText } from "$lib/nlp/tokenization";
  import { tokenBlocks, type TokenBlock } from "./tokens";

  let {
    text,
    start,
    root,
    selectedStart,
    onToken,
  }: {
    text: string;
    start: number;
    root: HTMLElement | undefined;
    selectedStart: number | undefined;
    onToken: (token: TokenBlock) => void;
  } = $props();
  let element = $state<HTMLSpanElement>();
  let blocks = $state<TokenBlock[]>();
  let error = $state("");
  let loading = $state(false);
  let disposed = false;
  async function analyze() {
    if (loading || disposed) return;
    loading = true;
    error = "";
    try {
      const tokens = await tokenizeText(text);
      if (!disposed) blocks = tokenBlocks(text, tokens);
    } catch (cause) {
      if (!disposed) error = String(cause);
    } finally {
      if (!disposed) loading = false;
    }
  }
  $effect(() => {
    if (!element || !root) return;
    disposed = false;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          observer.disconnect();
          void analyze();
        }
      },
      { root, rootMargin: "200px" },
    );
    observer.observe(element);
    return () => {
      disposed = true;
      observer.disconnect();
    };
  });
</script>

<span bind:this={element}>
  {#if blocks}{#each blocks as block (block.start)}{#if block.morphemes.length}<span
          role="button"
          tabindex="0"
          class="cursor-pointer text-inherit hover:text-primary hover:underline hover:decoration-dotted hover:underline-offset-4 focus-visible:rounded-sm focus-visible:outline-2 focus-visible:outline-ring aria-pressed:text-primary"
          data-testid={`token-${start + block.start}`}
          aria-label={`Analyze ${block.text}`}
          aria-pressed={selectedStart === start + block.start}
          onclick={() => onToken({ ...block, start: start + block.start, end: start + block.end })}
          onkeydown={(event) => {
            if (event.key === "Enter" || event.key === " ") {
              event.preventDefault();
              onToken({ ...block, start: start + block.start, end: start + block.end });
            }
          }}
        >
          {block.text}
        </span>{:else}{block.text}{/if}{/each}{:else}{text}{/if}{#if error}<span
      class="text-sm text-destructive"
      role="alert"
    >
      {error}
      <button type="button" class="underline" disabled={loading} onclick={analyze}>
        Retry token analysis
      </button>
    </span>{/if}
</span>
