<script lang="ts">
  import { ExternalLink, Search, Trash2 } from "@lucide/svelte";
  import { onMount } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import { parseYouTubeLink } from "$lib/dashboard/youtube";
  import { loadLibraryState } from "$lib/library/commands";
  import {
    addSubscription,
    removeSubscription,
    removeYouTubeKey,
    saveYouTubeKey,
    saveYouTubeProgress,
    searchYouTube,
    subscriptions,
    subscriptionFeed,
    youtubeSettings,
    type Subscription,
    type YouTubeVideo,
  } from "$lib/youtube/commands";

  let link = $state("");
  let query = $state("");
  let results = $state<YouTubeVideo[]>([]);
  let nextPage = $state("");
  let error = $state("");
  let hasKey = $state(false);
  let apiKey = $state("");
  let channelInput = $state("");
  let channelList = $state<Subscription[]>([]);
  let feed = $state<YouTubeVideo[]>([]);
  let history = $state<Record<string, number>>({});

  function report(reply: { ok: boolean; error: string }) {
    if (!reply.ok) error = reply.error;
    return reply.ok;
  }

  async function refreshState() {
    const state = await loadLibraryState();
    if (!state.ok) {
      error = state.error;
      return;
    }
    const entries = (state.data?.youtubeHistory ?? []) as { youtubeId: string; seconds: number }[];
    history = Object.fromEntries(entries.map((entry) => [entry.youtubeId, entry.seconds]));
  }

  async function refreshSettings() {
    const reply = await youtubeSettings();
    if (!reply.ok || !reply.data) return;
    hasKey = reply.data.hasKey;
  }

  async function refreshSubscriptions() {
    const reply = await subscriptions();
    if (report(reply)) channelList = reply.data ?? [];
  }

  onMount(() => {
    void (async () => {
      await refreshState();
      const id = new URLSearchParams(location.hash.split("?")[1] ?? "").get("v");
      if (id && /^[\w-]{11}$/.test(id)) await play(id);
    })();
    void refreshSettings();
    void refreshSubscriptions();
  });

  async function play(id: string, _title = "", _channel = "") {
    location.hash = `#/watch?v=${encodeURIComponent(id)}`;
  }

  function openLink() {
    const id = parseYouTubeLink(link);
    if (!id) {
      error = "Paste a valid YouTube video link.";
      return;
    }
    void play(id);
  }

  async function doSearch() {
    const reply = await searchYouTube(query, nextPage);
    if (!report(reply)) return;
    results = reply.data?.videos ?? [];
    nextPage = reply.data?.nextPageToken ?? "";
  }

  async function saveKey() {
    const reply = await saveYouTubeKey(apiKey);
    if (!report(reply)) return;
    apiKey = "";
    await refreshSettings();
  }

  async function addChannel() {
    const reply = await addSubscription(channelInput);
    if (!report(reply)) return;
    channelInput = "";
    await refreshSubscriptions();
  }

  async function loadFeed() {
    const reply = await subscriptionFeed();
    if (report(reply)) feed = reply.data?.videos ?? [];
  }
</script>

<div class="flex flex-col gap-4">
  <div class="flex flex-wrap items-center gap-2">
    <Input
      class="max-w-md"
      placeholder="Paste a YouTube link"
      aria-label="YouTube link"
      bind:value={link}
    />
    <Button onclick={openLink}>Play</Button>
    <span class="ml-auto text-sm text-muted-foreground">
      {hasKey ? "API key saved" : "No API key"}
    </span>
  </div>

  {#if error}
    <p class="text-sm text-destructive" role="alert" data-testid="youtube-error">{error}</p>
  {/if}

  <section class="flex flex-col gap-2">
    <h2 class="text-sm font-semibold text-muted-foreground">Search</h2>
    <div class="flex flex-wrap gap-2">
      <Input
        class="max-w-sm"
        placeholder="Search videos"
        aria-label="Search YouTube"
        bind:value={query}
      />
      <Button variant="outline" onclick={doSearch} data-testid="youtube-search">Search</Button>
    </div>
    {#if results.length}
      <ul class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3" data-testid="youtube-results">
        {#each results as video (video.id)}
          <li class="flex gap-2 rounded-lg border border-border bg-card p-2">
            <img class="h-12 w-20 rounded object-cover" src={video.thumbnail} alt="" />
            <button
              type="button"
              class="flex-1 text-left text-sm"
              data-testid={`youtube-result-${video.id}`}
              onclick={() => void play(video.id, video.title, video.channel)}
            >
              <span class="block truncate font-medium">{video.title}</span>
              <span class="block text-xs text-muted-foreground">{video.channel}</span>
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  </section>

  <section class="flex flex-col gap-2">
    <h2 class="text-sm font-semibold text-muted-foreground">Settings & subscriptions</h2>
    {#if !hasKey}
      <div class="flex flex-wrap gap-2">
        <Input
          class="max-w-sm"
          type="password"
          placeholder="YouTube Data API key"
          aria-label="YouTube API key"
          bind:value={apiKey}
        />
        <Button variant="outline" onclick={saveKey}>Save key</Button>
      </div>
    {:else}
      <Button variant="outline" onclick={removeYouTubeKey}>Remove key</Button>
    {/if}
    <div class="flex flex-wrap gap-2">
      <Input
        class="max-w-sm"
        placeholder="Channel link or handle"
        aria-label="Channel"
        bind:value={channelInput}
      />
      <Button variant="outline" onclick={addChannel}>Add channel</Button>
      <Button variant="outline" onclick={loadFeed} data-testid="youtube-feed">Load feed</Button>
    </div>
    {#if channelList.length}
      <ul class="flex flex-wrap gap-2">
        {#each channelList as item (item.channelId)}
          <li class="flex items-center gap-1 rounded-md border border-border px-2 py-1 text-sm">
            {item.title}
            <button
              type="button"
              aria-label={`Remove ${item.title}`}
              onclick={() => void removeSubscription(item.channelId)}
            >
              <Trash2 size={12} />
            </button>
          </li>
        {/each}
      </ul>
    {/if}
    {#if feed.length}
      <ul class="flex flex-col gap-1" data-testid="youtube-feed-list">
        {#each feed as video (video.id)}
          <li>
            <button
              type="button"
              class="text-left text-sm underline"
              onclick={() => void play(video.id, video.title, video.channel)}
            >
              {video.title}
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  </section>

  {#if Object.keys(history).length}
    <section>
      <h2 class="mb-2 text-sm font-semibold text-muted-foreground">Recent</h2>
      <ul class="flex flex-wrap gap-2">
        {#each Object.entries(history) as [id, seconds] (id)}
          <li>
            <button
              type="button"
              class="rounded-md border border-border px-2 py-1 text-sm"
              onclick={() => void play(id, "", "")}
            >
              {id.slice(0, 8)}… · {Math.floor(seconds)}s
            </button>
          </li>
        {/each}
      </ul>
    </section>
  {/if}

  <p class="text-xs text-muted-foreground">
    <ExternalLink size={12} class="inline" />
    Videos play in an embedded YouTube iframe; core reading, playback and analysis stay offline.
  </p>
</div>
