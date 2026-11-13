<script lang="ts">
  import { page } from "$app/state";
  import { resolve } from "$app/paths";
  import { ArrowLeft, Captions, ExternalLink } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import { readProgress, saveProgress, trackPlayback } from "$lib/features/dashboard/playback";
  import { fetchYouTubeMetadata } from "$lib/features/dashboard/youtube";

  let metadata = $state<{ id: string; title: string; channel: string }>();

  const video = $derived.by(() => {
    const id = page.url.searchParams.get("v");
    if (!id || !/^[\w-]{11}$/.test(id)) return;

    const progress = readProgress();
    const saved = progress?.id === id ? progress : undefined;
    return {
      id,
      title: page.url.searchParams.get("title")?.trim() || saved?.title || "",
      channel: page.url.searchParams.get("channel")?.trim() || saved?.channel || "",
      seconds: saved?.seconds ?? 0,
      duration: saved?.duration,
    };
  });

  const title = $derived(
    (video && metadata?.id === video.id && metadata.title) || video?.title || "YouTube video",
  );

  $effect(() => {
    if (!video || (video.title && video.title !== "YouTube video" && video.channel)) return;
    const { id } = video;
    const request = new AbortController();
    void fetchYouTubeMetadata(id, request.signal)
      .then((details) => {
        if (details && !request.signal.aborted) metadata = { id, ...details };
      })
      .catch(() => {
        // Keep the fallback title when metadata is unavailable.
      });
    return () => request.abort();
  });
</script>

<svelte:head>
  <title>{video ? title : "Watch"} · Sori</title>
</svelte:head>

<header class="border-b">
  <div class="mx-auto flex h-14 max-w-6xl items-center gap-2 px-4 sm:px-8">
    <Sidebar.Trigger class="md:hidden" />
    <Button href={resolve("/")} variant="ghost" size="sm"><ArrowLeft /> Home</Button>
  </div>
</header>

<div class="mx-auto max-w-6xl px-4 py-6 sm:px-8">
  {#if video}
    {@const current = video}
    {#key current.id}
      <iframe
        class="block aspect-video min-h-[200px] w-full rounded-xl bg-black"
        {title}
        src={`https://www.youtube.com/embed/${current.id}?cc_lang_pref=ko&enablejsapi=1&start=${current.seconds}`}
        use:trackPlayback={(seconds, duration) =>
          saveProgress(
            {
              ...current,
              duration: duration ?? current.duration,
              title:
                (metadata?.id === current.id && metadata.title) || current.title || "YouTube video",
              channel: current.channel || (metadata?.id === current.id ? metadata.channel : ""),
            },
            seconds,
          )}
        referrerpolicy="strict-origin-when-cross-origin"
        allow="encrypted-media; picture-in-picture; fullscreen"
        allowfullscreen
      ></iframe>
    {/key}

    <div class="mt-4 flex flex-wrap items-start justify-between gap-3">
      <h1 class="min-w-0 flex-1 text-xl leading-snug font-semibold wrap-break-word">{title}</h1>
      <Button
        href={`https://www.youtube.com/watch?v=${current.id}`}
        target="_blank"
        rel="noopener"
        variant="outline"
        size="sm">Open on YouTube <ExternalLink /></Button
      >
    </div>

    <section aria-labelledby="subtitles-heading" class="mt-6 rounded-xl border bg-card p-5 sm:p-6">
      <h2 id="subtitles-heading" class="flex items-center gap-2 font-semibold">
        <Captions class="size-4 text-muted-foreground" /> Subtitles and word mining
      </h2>
      <p class="mt-2 text-sm text-muted-foreground">
        Use the player’s CC control for available captions. Interactive subtitles and word mining are
        coming later.
      </p>
    </section>
  {:else}
    <h1 class="text-xl font-semibold">Video unavailable</h1>
    <p class="mt-2 text-sm text-muted-foreground">
      Choose a video from Discover or paste a YouTube link on Home.
    </p>
  {/if}
</div>
