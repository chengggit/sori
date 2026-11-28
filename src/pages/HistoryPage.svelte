<script lang="ts" module>
  let savedScroll = 0;
</script>

<script lang="ts">
  import { onMount, tick } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import HistoryRow from "$lib/history/HistoryRow.svelte";
  import { HistoryModel } from "$lib/history/state.svelte";
  import type { HistoryEntry } from "$lib/history/entries";
  import { platform } from "../platform";
  const history = new HistoryModel();
  const entries = $derived(history.entries);
  onMount(() => {
    const scroller = document.querySelector<HTMLElement>('[data-testid="page-content"]');
    let active = true,
      restoring = true,
      position = savedScroll;
    const recordScroll = () => {
      if (!restoring && scroller) position = scroller.scrollTop;
    };
    scroller?.addEventListener("scroll", recordScroll);
    void history.load().then(async () => {
      await tick();
      if (!active) return;
      if (scroller) scroller.scrollTop = position;
      restoring = false;
    });
    const unsubscribe = platform.onEvent("library-changed", () => void history.load());
    return () => {
      active = false;
      savedScroll = position;
      scroller?.removeEventListener("scroll", recordScroll);
      history.destroy();
      unsubscribe();
    };
  });
  async function open(event: MouseEvent, entry: HistoryEntry) {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.altKey || event.shiftKey) return;
    event.preventDefault();
    const href = await history.open(entry);
    if (href) location.hash = href;
  }
</script>

<section
  aria-label="Watch history"
  aria-busy={history.loading || history.refreshing}
  data-testid="history-page"
>
  {#if history.error}<div class="history-error" role="alert">
      <p>{history.error}</p>
      <Button
        variant="outline"
        size="sm"
        disabled={history.refreshing}
        onclick={() => void history.load()}
      >
        Retry
      </Button>
    </div>{/if}
  {#if history.openError}<div class="history-error" role="alert">
      <p>{history.openError}</p>
      <a href="#/library" class="text-sm underline">Open Library</a>
    </div>{/if}
  {#if history.loading}<p role="status" class="text-sm text-muted-foreground">
      Loading watch history…
    </p>{/if}
  {#if entries.length}<ul class="history-list">
      {#each entries as entry (entry.key)}<li>
          <HistoryRow
            {entry}
            opening={history.opening === entry.key}
            onOpen={(event) => void open(event, entry)}
            onVisible={() => history.requestThumbnail(entry)}
            onArtworkError={() => history.requestThumbnail(entry, true)}
            artworkVersion={entry.id ? (history.artworkVersions[entry.id] ?? 0) : 0}
          />
        </li>{/each}
    </ul>
  {:else if !history.loading && !history.error}<div class="empty-history">
      <h2 class="font-semibold">No watch history yet</h2>
      <p class="mt-1 text-sm text-muted-foreground">Videos you play in Sori will appear here.</p>
      <Button href="#/explore" variant="outline" class="mt-4">Explore videos</Button>
    </div>{/if}
</section>

<style>
  .history-list {
    display: grid;
    gap: 16px;
  }
  .history-error {
    display: flex;
    gap: 12px;
    align-items: center;
    flex-wrap: wrap;
    margin-bottom: 12px;
    color: var(--destructive);
    font-size: 14px;
  }
  .empty-history {
    padding: 24px;
    border: 1px solid var(--border);
    border-radius: 12px;
    background: var(--card);
  }
</style>
