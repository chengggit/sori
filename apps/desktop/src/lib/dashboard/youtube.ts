export type YouTubeVideo = {
  id: string;
  title: string;
  channel: string;
  thumbnail: string;
};

export type YouTubeSearchPage = { videos: YouTubeVideo[]; nextPageToken?: string };

const videoId = /^[\w-]{11}$/;
const searchCacheKey = 'sori-youtube-search-cache';
const cacheLifetime = 24 * 60 * 60 * 1000;

type CachedSearch = { query: string; expiresAt: number; videos: YouTubeVideo[] };

export function parseYouTubeLink(input: string): string | null {
  try {
    const url = new URL(input.trim());
    if (url.protocol !== 'https:' && url.protocol !== 'http:') return null;
    let id: string | null = null;
    if (url.hostname === 'youtu.be') {
      id = url.pathname.slice(1);
    } else if (['youtube.com', 'www.youtube.com', 'm.youtube.com'].includes(url.hostname)) {
      id =
        url.pathname === '/watch'
          ? url.searchParams.get('v')
          : (url.pathname.match(/^\/(?:shorts|live|embed)\/([\w-]+)$/)?.[1] ?? null);
    }
    return id && videoId.test(id) ? id : null;
  } catch {
    return null;
  }
}

export function parseIsoDuration(text: string | undefined): number | undefined {
  const parts = text?.match(/^P(?:(\d+)D)?T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/);
  if (!parts) return undefined;
  const [, days = '0', hours = '0', minutes = '0', seconds = '0'] = parts;
  const total = Number(days) * 86400 + Number(hours) * 3600 + Number(minutes) * 60 + Number(seconds);
  return Number.isFinite(total) && total > 0 ? total : undefined;
}

export function parseYouTubeDuration(data: unknown): number | undefined {
  if (!data || typeof data !== 'object') return undefined;
  const items = (data as { items?: unknown[] }).items;
  if (!Array.isArray(items)) return undefined;
  const first = items[0] as { contentDetails?: { duration?: string } } | undefined;
  return parseIsoDuration(first?.contentDetails?.duration);
}

export function parseYouTubeMetadata(data: unknown): { title: string; channel: string } | undefined {
  if (!data || typeof data !== 'object') return undefined;
  const value = data as { title?: unknown; author_name?: unknown };
  return {
    title: typeof value.title === 'string' ? value.title.trim() : '',
    channel: typeof value.author_name === 'string' ? value.author_name.trim() : '',
  };
}

type SearchItem = {
  id: { videoId?: string };
  snippet: {
    title: string;
    channelTitle: string;
    thumbnails: { medium?: { url: string }; default: { url: string } };
  };
};

export function parseYouTubeSearch(data: unknown): YouTubeSearchPage {
  if (!data || typeof data !== 'object') return { videos: [] };
  const value = data as { items?: SearchItem[]; nextPageToken?: string };
  const videos = (Array.isArray(value.items) ? value.items : []).flatMap(({ id, snippet }) =>
    id?.videoId && videoId.test(id.videoId)
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
  return { videos, nextPageToken: value.nextPageToken };
}

/** Translate Data API failures into user-facing messages without echoing the body. */
export function youtubeSearchError(status: number, reason?: string): string | null {
  if (reason === 'quotaExceeded' || reason === 'dailyLimitExceeded') {
    return 'This project has reached its daily YouTube search quota. Try a cached topic or paste a video link.';
  }
  if (status === 429 || reason === 'rateLimitExceeded' || reason === 'userRateLimitExceeded') {
    return 'YouTube is limiting search requests. Wait a moment and try again.';
  }
  if (status === 403) return 'YouTube denied the search request. Check your API key and its restrictions.';
  return status >= 400 ? 'Could not load YouTube videos. Try again.' : null;
}

export function readYouTubeSearchCache(query: string): YouTubeVideo[] | undefined {
  try {
    const entries = JSON.parse(localStorage.getItem(searchCacheKey) ?? '[]') as CachedSearch[];
    const valid = entries.filter((entry) => entry.expiresAt > Date.now() && Array.isArray(entry.videos));
    return valid.find((entry) => entry.query === query)?.videos;
  } catch {
    return undefined;
  }
}

export function cacheYouTubeSearch(query: string, videos: YouTubeVideo[]) {
  try {
    const entries = JSON.parse(localStorage.getItem(searchCacheKey) ?? '[]') as CachedSearch[];
    const valid = entries.filter((entry) => entry.expiresAt > Date.now() && Array.isArray(entry.videos));
    valid.unshift({ query, videos, expiresAt: Date.now() + cacheLifetime });
    localStorage.setItem(searchCacheKey, JSON.stringify(valid.slice(0, 30)));
  } catch {
    // Search still works when local storage is unavailable.
  }
}
