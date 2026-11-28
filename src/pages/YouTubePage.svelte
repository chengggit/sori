<script lang="ts">
  import { ExternalLink, Search, Trash2 } from "@lucide/svelte";
  import { onDestroy, onMount, tick } from "svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import { parseYouTubeLink } from "$lib/dashboard/youtube";
  import { trackPlayback } from "$lib/dashboard/playback";
  import type { PlaybackControls } from "$lib/video/playback";
  import { loadLibraryState } from "$lib/library/commands";
  import {
    addSubscription,
    fetchTranscript,
    fetchMetadata,
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
  let current = $state<string | null>(null);
  let title = $state("");
  let channel = $state("");
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
  let transcript = $state("");

  let frame = $state<HTMLIFrameElement>();
  let controls: PlaybackControls | undefined;
  let tracker: { destroy(): void } | undefined;
  let savedSeconds = 0;
  let currentDuration = 0;

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

  onDestroy(() => tracker?.destroy());

  async function play(id: string, videoTitle = "", videoChannel = "") {
    tracker?.destroy();
    tracker = undefined;
    controls = undefined;
    current = id;
    title = videoTitle;
    channel = videoChannel;
    transcript = "";
    savedSeconds = history[id] ?? 0;
    currentDuration = 0;
    if (!videoTitle) {
      const info = await fetchMetadata(id);
      if (report(info) && info.data) {
        title = info.data.title;
        channel = info.data.channel;
      }
    }
    // Let Svelte create the iframe with the new src before attaching the API.
    await tick();
    if (frame) {
      tracker = trackPlayback(frame, {
        onTime: () => {},
        onSave: async (seconds, duration) => {
          if (!current) return;
          currentDuration = duration ?? currentDuration;
          const saved = await saveYouTubeProgress(current, title, channel, seconds, currentDuration);
          report(saved);
        },
        onControls: (next) => {
          controls = next;
          if (next && savedSeconds > 0) next.seek(savedSeconds);
        },
      });
    }
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

  async function loadTranscript() {
    if (!current) return;
    const reply = await fetchTranscript(current, "ko");
    if (!report(reply)) return;
    const data = reply.data as { timedJson?: unknown } | null;
    const cues = data?.timedJson;
    transcript = Array.isArray(cues) ? `${cues.length} timed cues cached` : "No timed captions found.";
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

  {#if current}
    <section class="rounded-lg border border-border bg-card p-3" data-testid="youtube-player">
      <h2 class="mb-2 font-semibold">{title || "YouTube video"}</h2>
      <div class="aspect-video w-full max-w-3xl overflow-hidden rounded-lg bg-black">
        <iframe
          bind:this={frame}
          class="h-full w-full border-0"
          src={`https://www.youtube.com/embed/${current}?enablejsapi=1`}
          title={title || "YouTube player"}
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; picture-in-picture"
          allowfullscreen
        ></iframe>
      </div>
      <div class="mt-2 flex flex-wrap gap-2">
        <Button variant="outline" onclick={() => controls?.play()}>Play</Button>
        <Button variant="outline" onclick={() => controls?.pause()}>Pause</Button>
        <Button variant="outline" onclick={loadTranscript} data-testid="fetch-transcript">
          Fetch captions
        </Button>
        {#if transcript}<span class="text-sm text-muted-foreground">{transcript}</span>{/if}
      </div>
    </section>
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
