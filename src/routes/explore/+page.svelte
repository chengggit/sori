<script lang="ts">
  import { onDestroy } from "svelte";
  import { resolve } from "$app/paths";
  import { Search } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import { Input } from "$lib/components/ui/input";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import { searchYouTube, type YouTubeVideo } from "$lib/features/dashboard/youtube";

  const key = import.meta.env.VITE_YOUTUBE_API_KEY?.trim();
  const topics = [
    { name: "History", query: "한국 역사 다큐 한국어 자막" },
    { name: "Science & nature", query: "과학 자연 다큐 한국어 자막" },
    { name: "Food & cooking", query: "한국 전통 음식 요리 한국어 자막" },
    { name: "Comedy", query: "한국 코미디 스케치 한국어 자막" },
    { name: "Interviews", query: "한국 직업 인터뷰 한국어 자막" },
    { name: "Arts & crafts", query: "한국 공예 작업실 한국어 자막" },
    { name: "Music", query: "한국 음악 공연 인터뷰 한국어 자막" },
    { name: "Daily life", query: "한국 시골 일상 브이로그 한국어 자막" },
  ];

  let search = $state("");
  let selection = $state<{ name: string; query: string; topic?: boolean }>();
  let videos = $state<YouTubeVideo[]>([]);
  let loading = $state(false);
  let error = $state("");
  let request: AbortController | undefined;

  onDestroy(() => request?.abort());

  async function browse(next: NonNullable<typeof selection>) {
    if (!key) return;
    request?.abort();
    const current = new AbortController();
    request = current;
    selection = next;
    loading = true;
    error = "";
    videos = [];

    try {
      const results = await searchYouTube(key, next.query, current.signal);
      if (!current.signal.aborted) videos = results.videos;
    } catch (cause) {
      if (!current.signal.aborted) {
        error = cause instanceof Error ? cause.message : "Could not load YouTube videos.";
      }
    } finally {
      if (!current.signal.aborted) loading = false;
    }
  }

  function chooseTopic(topic: (typeof topics)[number]) {
    search = "";
    void browse({ ...topic, topic: true });
  }
</script>

<svelte:head>
  <title>Explore · Sori</title>
</svelte:head>

<header class="border-b">
  <div class="mx-auto flex h-14 max-w-6xl items-center gap-2 px-4 sm:px-8">
    <Sidebar.Trigger class="md:hidden" />
    <h1 class="text-lg font-semibold">Explore</h1>
  </div>
</header>

<div class="mx-auto max-w-6xl space-y-8 px-4 py-6 sm:px-8">
  {#if key}
    <form
      class="flex max-w-xl gap-2"
      onsubmit={(event) => {
        event.preventDefault();
        const query = search.trim();
        if (query) void browse({ name: query, query });
      }}
    >
      <Input bind:value={search} aria-label="Search Korean videos" placeholder="Search Korean videos" />
      <Button type="submit" disabled={!search.trim()}><Search /> Search</Button>
    </form>

    <section aria-labelledby="explore-topics" class="pt-4">
      <div class="mb-4 flex flex-wrap items-center gap-3">
        <h2 id="explore-topics" class="text-xl font-semibold">Browse by topic</h2>
      </div>
      <div class="flex flex-wrap gap-2">
        {#each topics as topic (topic.query)}
          {@const selected = selection?.topic && selection.query === topic.query}
          <Button
            variant={selected ? "default" : "outline"}
            class="rounded-full"
            aria-pressed={!!selected}
            onclick={() => chooseTopic(topic)}>{topic.name}</Button
          >
        {/each}
      </div>
    </section>

    {#if selection}
      {@const current = selection}
      <section aria-labelledby="explore-results" aria-busy={loading}>
        <h2 id="explore-results" class="mb-4 text-xl font-semibold">
          {current.topic ? current.name : `Results for “${current.name}”`}
        </h2>
        {#if loading}
          <p role="status" class="text-sm text-muted-foreground">Loading YouTube videos…</p>
        {:else if error}
          <p role="alert" class="text-sm text-destructive">{error}</p>
          <Button variant="outline" class="mt-3" onclick={() => void browse(current)}>Retry</Button>
        {:else if !videos.length}
          <p class="text-sm text-muted-foreground">
            No embeddable videos found. Try another topic or search.
          </p>
        {:else}
          <div class="grid gap-x-5 gap-y-6 min-[480px]:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {#each videos as video (video.id)}
              {@const query = new URLSearchParams({
                v: video.id,
                title: video.title,
                channel: video.channel,
              })}
              <a
                href={resolve(`/watch?${query}`)}
                class="group min-w-0 rounded-xl focus-visible:outline-2 focus-visible:outline-ring"
              >
                <div class="aspect-video overflow-hidden rounded-xl bg-muted">
                  <img
                    src={video.thumbnail}
                    alt=""
                    loading="lazy"
                    class="size-full object-cover transition group-hover:scale-[1.02] motion-reduce:transition-none"
                  />
                </div>
                <h3
                  title={video.title}
                  class="mt-2 line-clamp-2 text-sm font-semibold wrap-break-word group-hover:underline"
                >
                  {video.title}
                </h3>
                <p class="text-xs text-muted-foreground">{video.channel}</p>
              </a>
            {/each}
          </div>
        {/if}
      </section>
    {/if}
  {:else}
    <p class="text-sm text-muted-foreground">
      Explore requires a configured YouTube API key. You can still open a video from its link on Home.
    </p>
  {/if}
</div>
