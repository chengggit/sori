export type YouTubeVideo = {
  id: string;
  title: string;
  channel: string;
  thumbnail: string;
};

const videoId = /^[\w-]{11}$/;

export async function fetchYouTubeDuration(key: string, id: string, signal: AbortSignal) {
  const params = new URLSearchParams({ key, id, part: "contentDetails" });
  const response = await fetch(`https://www.googleapis.com/youtube/v3/videos?${params}`, { signal });
  if (!response.ok) return;

  const data: { items?: { contentDetails?: { duration?: string } }[] } = await response.json();
  const duration = data.items?.[0]?.contentDetails?.duration;
  const parts = duration?.match(/^P(?:(\d+)D)?T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/);
  if (!parts) return;
  const [, days = "0", hours = "0", minutes = "0", seconds = "0"] = parts;
  const total = Number(days) * 86400 + Number(hours) * 3600 + Number(minutes) * 60 + Number(seconds);
  if (Number.isFinite(total) && total > 0) return total;
}

export async function fetchYouTubeMetadata(id: string, signal: AbortSignal) {
  const params = new URLSearchParams({
    url: `https://www.youtube.com/watch?v=${id}`,
    format: "json",
  });
  const response = await fetch(`https://www.youtube.com/oembed?${params}`, { signal });
  if (!response.ok) return;

  const data: { title?: unknown; author_name?: unknown } = await response.json();
  return {
    title: typeof data.title === "string" ? data.title.trim() : "",
    channel: typeof data.author_name === "string" ? data.author_name.trim() : "",
  };
}
const searchCacheKey = "sori-youtube-search-cache";
const cacheLifetime = 24 * 60 * 60 * 1000;
type CachedSearch = { query: string; expiresAt: number; videos: YouTubeVideo[] };

function readSearchCache(): CachedSearch[] {
  try {
    const entries = JSON.parse(localStorage.getItem(searchCacheKey) ?? "[]") as CachedSearch[];
    return entries.filter((entry) => entry.expiresAt > Date.now() && Array.isArray(entry.videos));
  } catch {
    return [];
  }
}

export function parseYouTubeLink(input: string): string | null {
  try {
    const url = new URL(input.trim());
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;

    let id: string | null = null;
    if (url.hostname === "youtu.be") {
      id = url.pathname.slice(1);
    } else if (["youtube.com", "www.youtube.com", "m.youtube.com"].includes(url.hostname)) {
      id =
        url.pathname === "/watch"
          ? url.searchParams.get("v")
          : (url.pathname.match(/^\/(?:shorts|live|embed)\/([\w-]+)$/)?.[1] ?? null);
    }

    return id && videoId.test(id) ? id : null;
  } catch {
    return null;
  }
}

type SearchItem = {
  id: { videoId?: string };
  snippet: {
    title: string;
    channelTitle: string;
    thumbnails: { medium?: { url: string }; default: { url: string } };
  };
};

export async function searchYouTube(
  key: string,
  query: string,
  signal: AbortSignal,
): Promise<YouTubeVideo[]> {
  const cached = readSearchCache().find((entry) => entry.query === query);
  if (cached) return cached.videos;

  const params = new URLSearchParams({
    part: "snippet",
    type: "video",
    q: query,
    relevanceLanguage: "ko",
    videoEmbeddable: "true",
    maxResults: "12",
    key,
  });
  const response = await fetch(`https://www.googleapis.com/youtube/v3/search?${params}`, { signal });

  if (!response.ok) {
    const body = await response.json().catch(() => undefined);
    const reason = body?.error?.errors?.[0]?.reason;
    if (reason === "quotaExceeded" || reason === "dailyLimitExceeded") {
      throw new Error(
        "This project has reached its daily YouTube search quota. Try a cached topic or paste a video link.",
      );
    }
    if (
      response.status === 429 ||
      reason === "rateLimitExceeded" ||
      reason === "userRateLimitExceeded"
    ) {
      throw new Error("YouTube is limiting search requests. Wait a moment and try again.");
    }
    throw new Error(
      response.status === 403
        ? "YouTube denied the search request. Check your API key and its restrictions."
        : "Could not load YouTube videos. Try again.",
    );
  }

  const data: { items: SearchItem[] } = await response.json();
  const videos = data.items.flatMap(({ id, snippet }) =>
    id.videoId && videoId.test(id.videoId)
      ? [
          {
            id: id.videoId,
            title: snippet.title,
            channel: snippet.channelTitle,
            thumbnail: snippet.thumbnails.medium?.url ?? snippet.thumbnails.default.url,
          },
        ]
      : [],
  );
  if (!signal.aborted) {
    try {
      const entries = readSearchCache().filter((entry) => entry.query !== query);
      entries.unshift({ query, videos, expiresAt: Date.now() + cacheLifetime });
      localStorage.setItem(searchCacheKey, JSON.stringify(entries.slice(0, 30)));
    } catch {
      // Search still works when local storage is unavailable.
    }
  }
  return videos;
}
