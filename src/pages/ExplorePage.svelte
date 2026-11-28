<script lang="ts">
  import { onMount, tick } from "svelte";
  import { Search, Play, RefreshCw, Users, Trash2, Plus } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import * as Sheet from "$lib/components/ui/sheet";
  import VideoGrid from "$lib/youtube/VideoGrid.svelte";
  import VideoLinkDialog from "$lib/youtube/VideoLinkDialog.svelte";
  import { Explore } from "$lib/explore/state.svelte";
  import { topics } from "$lib/explore/topics";

  const model = new Explore();
  const discovery = model.discovery;
  let query = $state("");
  let linkOpen = $state(false),
    subscriptionsOpen = $state(false);
  let scroller: HTMLElement | null = null;
  let active = true;
  const busy = $derived(discovery.loading || discovery.loadingMore);
  onMount(() => {
    scroller = document.querySelector<HTMLElement>('[data-testid="page-content"]');
    const oldId = new URLSearchParams(location.hash.split("?")[1] ?? "").get("v");
    if (oldId && /^[\w-]{11}$/.test(oldId)) location.hash = `#/watch?v=${oldId}&from=explore`;
    void model.initialize().then(async () => {
      if (!active) return;
      query = model.selection?.kind === "search" ? model.selection.query : "";
      await tick();
      if (active && scroller) scroller.scrollTop = model.restoreScroll;
    });
    function nearEnd() {
      if (!scroller || discovery.error || busy || scroller.scrollTop <= 0) return;
      if (scroller.scrollHeight - scroller.clientHeight - scroller.scrollTop < 500) void model.more();
    }
    scroller?.addEventListener("scroll", nearEnd);
    return () => {
      active = false;
      model.destroy(scroller?.scrollTop ?? 0);
      scroller?.removeEventListener("scroll", nearEnd);
    };
  });
  function browse(value: string, label = value) {
    query = value;
    void model.browse(value, label);
    if (scroller) scroller.scrollTop = 0;
  }
</script>

<div class="explore" data-testid="explore-page">
  <div class="toolbar">
    <form
      role="search"
      class="search"
      onsubmit={(event) => {
        event.preventDefault();
        if (discovery.hasKey) browse(query);
      }}
    >
      <div class="search-field">
        <Search size={16} aria-hidden="true" /><Input
          aria-label="Search YouTube"
          placeholder="Search YouTube"
          bind:value={query}
          disabled={!discovery.configured || !discovery.hasKey}
        />
      </div>
      <Button
        variant="outline"
        size="icon"
        type="submit"
        aria-label="Search"
        data-testid="youtube-search"
        disabled={!discovery.hasKey || !query.trim()}
      >
        <Search size={16} />
      </Button>
    </form>
    <div class="actions">
      {#if model.selection}<Button
          variant="outline"
          size="icon"
          aria-label="Refresh videos"
          disabled={busy || !discovery.hasKey}
          onclick={() => void model.refresh()}
        >
          <RefreshCw size={16} />
        </Button>{/if}
      <Button variant="outline" onclick={() => (subscriptionsOpen = true)}>
        <Users size={15} />Subscriptions{#if discovery.channels.length}<span
            class="text-muted-foreground"
          >
            {discovery.channels.length}
          </span>{/if}
      </Button>
      <Button variant="outline" onclick={() => (linkOpen = true)}>
        <Play size={15} />Paste video link
      </Button>
    </div>
  </div>
  <nav class="topics" aria-label="Video topics">
    {#each topics as topic (topic.query)}<Button
        variant="outline"
        size="sm"
        class="topic"
        aria-pressed={model.selection?.kind === "search" && model.selection.query === topic.query}
        disabled={!discovery.hasKey}
        onclick={() => browse(topic.query, topic.label)}
      >
        {topic.label}
      </Button>{/each}
    <Button
      variant="outline"
      size="sm"
      class="topic feed-topic"
      aria-pressed={model.selection?.kind === "feed"}
      disabled={!discovery.hasKey}
      onclick={() => {
        query = "";
        void model.feed();
        if (scroller) scroller.scrollTop = 0;
      }}
    >
      Your feed
    </Button>
  </nav>
  {#if discovery.configurationError}<div class="status" role="alert">
      <p>{discovery.configurationError}</p>
      <Button variant="outline" size="sm" onclick={() => void model.reloadConfiguration()}>
        Retry settings
      </Button>
    </div>
  {:else if discovery.configured && !discovery.hasKey}<p
      class="status text-muted-foreground"
      role="status"
    >
      Add a YouTube API key in <a class="underline" href="#/settings">Settings</a> to search and browse topics.
      You can still paste a video link.
    </p>
  {:else if !discovery.configured}<p class="status text-muted-foreground" role="status">
      Loading Explore…
    </p>
  {:else if !model.selection}<p class="status text-muted-foreground" role="status">
      Choose a topic or search for Korean videos.
    </p>{/if}
  <section
    class="results"
    class:loading={discovery.loading}
    aria-label={model.selection?.kind === "feed"
      ? "Your subscription feed"
      : model.selection?.kind === "search"
        ? `Results for ${model.selection.label}`
        : "Videos"}
    aria-busy={busy}
    data-testid="youtube-results"
  >
    {#if discovery.error}<div class="status" role="alert">
        <p>{discovery.error}</p>
        <Button variant="outline" size="sm" onclick={() => void model.retry()}>Retry</Button>
      </div>{/if}
    {#if discovery.notice && model.selection}<p class="status text-muted-foreground" role="status">
        {discovery.notice}{#if model.selection.kind === "feed" && !discovery.channels.length}<button
            class="ml-1 underline"
            onclick={() => (subscriptionsOpen = true)}
          >
            Add a channel
          </button>{/if}
      </p>{/if}
    <div class="grid-region">
      {#if discovery.loading}<div class="loading-indicator" role="status">
          <span class="spinner" aria-hidden="true"></span><span class="sr-only">Loading videos…</span>
        </div>{/if}
      <VideoGrid videos={discovery.videos} from="explore" />
    </div>
    {#if discovery.hasMore}<div class="load-more">
        <Button variant="outline" disabled={busy} onclick={() => void model.more()}>
          {discovery.loadingMore ? "Loading…" : "Load more"}
        </Button>
      </div>{/if}
  </section>
</div>

<VideoLinkDialog bind:open={linkOpen} from="explore" />
<Sheet.Root bind:open={subscriptionsOpen}>
  <Sheet.Content class="w-[560px] max-w-[calc(100vw-32px)] rounded-2xl border-transparent gap-0 pb-0">
    <Sheet.Header>
      <Sheet.Title>Subscriptions</Sheet.Title><Sheet.Description>
        Add YouTube channels to build your feed.
      </Sheet.Description>
    </Sheet.Header>
    <div class="subscriptions-body">
      <form
        class="flex flex-wrap gap-2"
        onsubmit={(event) => {
          event.preventDefault();
          void model.addChannel();
        }}
      >
        <Input
          class="min-w-0 flex-1"
          aria-label="YouTube channel"
          placeholder="Channel link, @handle or channel ID"
          bind:value={model.channelInput}
          disabled={model.changingSubscriptions}
        /><Button
          type="submit"
          disabled={model.changingSubscriptions || !discovery.hasKey || !model.channelInput.trim()}
        >
          <Plus size={15} />{model.changingSubscriptions ? "Updating…" : "Add channel"}
        </Button>
      </form>
      {#if !discovery.hasKey}<p class="text-sm text-muted-foreground">
          Adding a channel requires a YouTube API key in <a href="#/settings" class="underline">
            Settings
          </a>.
        </p>{/if}
      {#if model.subscriptionError}<p class="text-sm text-destructive" role="alert">
          {model.subscriptionError}
        </p>{/if}
      {#if discovery.channelsError}<div role="alert" class="text-sm text-destructive">
          <p>{discovery.channelsError}</p>
          <Button variant="outline" size="sm" onclick={() => void model.reloadConfiguration()}>
            Retry subscriptions
          </Button>
        </div>{/if}
      {#if discovery.channels.length}<ul class="channel-list">
          {#each discovery.channels as channel (channel.channelId)}<li>
              <div class="min-w-0">
                <p class="truncate font-medium">{channel.title}</p>
                <p class="truncate text-xs text-muted-foreground">{channel.channelId}</p>
              </div>
              <Button
                variant="ghost"
                size="icon-sm"
                aria-label={`Remove ${channel.title}`}
                disabled={model.changingSubscriptions}
                onclick={() => void model.removeChannel(channel)}
              >
                <Trash2 size={15} />
              </Button>
            </li>{/each}
        </ul>
      {:else if !discovery.channelsError}<p class="text-sm text-muted-foreground">
          No subscriptions yet.
        </p>{/if}
      <div class="flex justify-end">
        <Button
          variant="outline"
          onclick={() => {
            subscriptionsOpen = false;
            query = "";
            void model.feed();
            if (scroller) scroller.scrollTop = 0;
          }}
          disabled={!discovery.hasKey}
        >
          View feed
        </Button>
      </div>
    </div>
  </Sheet.Content>
</Sheet.Root>

<style>
  .toolbar {
    display: flex;
    align-items: center;
    gap: 16px;
    justify-content: space-between;
    margin: 4px 0 14px;
    flex-wrap: wrap;
  }
  .search {
    display: flex;
    gap: 8px;
    flex: 1;
    min-width: 240px;
    max-width: 560px;
  }
  .search-field {
    position: relative;
    flex: 1;
    min-width: 0;
  }
  .search-field > :global(svg) {
    position: absolute;
    left: 12px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--muted-foreground);
    pointer-events: none;
    z-index: 1;
  }
  .search-field :global(input) {
    padding-left: 36px;
    border-radius: 12px;
  }
  .actions {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
  .topics {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
    margin-bottom: 14px;
  }
  :global(.topic[aria-pressed="true"]) {
    background: var(--chip);
    border-color: transparent;
    box-shadow: none;
  }
  :global(.feed-topic) {
    margin-left: auto;
  }
  .status {
    font-size: 14px;
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
    margin-bottom: 20px;
  }
  .grid-region {
    position: relative;
  }
  .loading .grid-region {
    min-height: 180px;
  }
  .loading-indicator {
    position: absolute;
    z-index: 2;
    top: 8px;
    left: 50%;
    transform: translateX(-50%);
    width: 48px;
    height: 48px;
    display: grid;
    place-items: center;
    background: var(--card);
    border-radius: 50%;
    box-shadow: 0 3px 14px #0003;
  }
  .spinner {
    width: 22px;
    height: 22px;
    border: 2px solid var(--chip);
    border-top-color: var(--dashboard-accent);
    border-radius: 50%;
    animation: spin 700ms linear infinite;
  }
  .load-more {
    display: flex;
    justify-content: center;
    padding: 24px 0;
  }
  .subscriptions-body {
    display: grid;
    gap: 16px;
    padding: 0 16px 20px;
  }
  .channel-list {
    max-height: 45vh;
    overflow: auto;
    display: grid;
    gap: 6px;
  }
  .channel-list li {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 10px 12px;
    font-size: 14px;
  }
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
  @media (max-width: 600px) {
    .search {
      max-width: none;
    }
    .actions {
      width: 100%;
    }
    :global(.feed-topic) {
      margin-left: 0;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .spinner {
      animation-duration: 1.6s;
    }
  }
</style>
