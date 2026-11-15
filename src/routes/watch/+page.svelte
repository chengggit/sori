<script lang="ts">
  import { page } from "$app/state";
  import { resolve } from "$app/paths";
  import { ArrowLeft } from "@lucide/svelte";
  import { Button } from "$lib/components/ui/button";
  import * as Sidebar from "$lib/components/ui/sidebar";
  import { readProgress, saveProgress } from "$lib/features/dashboard/playback";
  import { fetchYouTubeMetadata } from "$lib/features/dashboard/youtube";
  import WatchVideo from "$lib/features/video/WatchVideo.svelte";
  import { openVideo, saveVideoProgress, type LocalVideoDetails } from "$lib/features/video/local";

  let metadata = $state<{ id: string; title: string; channel: string }>();
  let localVideo = $state<LocalVideoDetails>();
  let localError = $state("");
  let progressError = $state("");
  let progressWrites = Promise.resolve();
  const localId = $derived(page.url.searchParams.get("local"));
  const currentLocal = $derived(String(localVideo?.id) === localId ? localVideo : undefined);

  $effect(() => {
    localVideo = undefined;
    localError = "";
    progressError = "";
    if (localId === null) return;
    const id = Number(localId);
    if (!Number.isSafeInteger(id) || id < 1 || String(id) !== localId) {
      localError = "Video not found.";
      return;
    }
    let active = true;
    void openVideo(id).then(
      (result) => {
        if (active) localVideo = result;
      },
      (cause) => {
        if (active) localError = String(cause);
      },
    );
    return () => {
      active = false;
    };
  });

  function saveLocalPosition(id: number, seconds: number, completed = false) {
    progressWrites = progressWrites.then(async () => {
      try {
        await saveVideoProgress(id, completed ? 0 : seconds);
        if (String(id) === localId) progressError = "";
      } catch (cause) {
        if (String(id) === localId) progressError = String(cause);
      }
    });
  }

  const video = $derived.by(() => {
    if (localId !== null) return;
    const id = page.url.searchParams.get("v");
    if (!id || !/^[\w-]{11}$/.test(id)) return;

    const saved = readProgress(id);
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
  <title>{currentLocal?.title ?? (video ? title : "Watch")} · Sori</title>
</svelte:head>

<header class="border-b">
  <div class="mx-auto flex h-14 max-w-6xl items-center gap-2 px-4 sm:px-8">
    <Sidebar.Trigger class="md:hidden" />
    <Button href={localId === null ? resolve("/") : resolve("/library")} variant="ghost" size="sm">
      <ArrowLeft />
      {localId === null ? "Home" : "My Library"}
    </Button>
  </div>
</header>

<div class="mx-auto max-w-6xl px-4 py-6 sm:px-8">
  {#if localId !== null}
    {#if currentLocal}
      {@const current = currentLocal}
      {#key current.id}
        <WatchVideo
          source={{ kind: "local", video: current }}
          title={current.title}
          start={current.seconds}
          onSaveProgress={(seconds, _duration, completed) =>
            saveLocalPosition(current.id, seconds, completed)}
        />
      {/key}
      {#if progressError}
        <p class="mt-2 text-sm text-destructive" role="alert">
          Could not save playback position. {progressError}
        </p>
      {/if}
    {:else if localError}
      <p class="text-sm text-destructive" role="alert">{localError}</p>
    {:else}
      <p class="text-sm text-muted-foreground" role="status">Opening video…</p>
    {/if}
  {:else if video}
    {@const current = video}
    {#key current.id}
      <WatchVideo
        source={{ kind: "youtube", id: current.id }}
        {title}
        start={current.seconds}
        onSaveProgress={(seconds, duration, completed) =>
          saveProgress(
            {
              ...current,
              duration: duration ?? current.duration,
              title:
                (metadata?.id === current.id && metadata.title) || current.title || "YouTube video",
              channel: current.channel || (metadata?.id === current.id ? metadata.channel : ""),
            },
            seconds,
            completed,
          )}
      />
    {/key}
  {:else}
    <h1 class="text-xl font-semibold">Video unavailable</h1>
    <p class="mt-2 text-sm text-muted-foreground">
      Choose a video from Discover or paste a YouTube link on Home.
    </p>
  {/if}
</div>
