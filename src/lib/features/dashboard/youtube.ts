export type YouTubeVideo = {
  id: string;
  title: string;
  channel: string;
  thumbnail: string;
};

const videoId = /^[\w-]{11}$/;

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
    throw new Error(
      response.status === 403 || response.status === 429
        ? "YouTube search is unavailable. Check the API key and project quota."
        : "Could not load YouTube videos. Try again.",
    );
  }

  const data: { items: SearchItem[] } = await response.json();
  return data.items.flatMap(({ id, snippet }) =>
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
}
