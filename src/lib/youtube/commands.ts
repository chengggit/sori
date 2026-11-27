import { platform } from "../../platform";

export type YouTubeVideo = {
  id: string;
  title: string;
  channel: string;
  thumbnail: string;
  publishedAt?: string;
};

export type YouTubeSearchPage = {
  videos: YouTubeVideo[];
  nextPageToken?: string;
};

export type Subscription = {
  channelId: string;
  title: string;
  uploadsPlaylistId: string;
};

export type YouTubeSettings = { hasKey: boolean; saved: boolean };

export function fetchMetadata(id: string) {
  return platform.invoke<{ title: string; channel: string }>("youtube:metadata", { id });
}

export function fetchDuration(id: string) {
  return platform.invoke<number>("youtube:duration", { id });
}

type VideoResult = Omit<YouTubeVideo, "thumbnail">;

// Rust returns video identity/metadata. Artwork URLs are derived by the UI,
// as in the Qt client; they are not fields in SearchVideo or FeedVideo.
function withThumbnail(video: VideoResult): YouTubeVideo {
  return {
    ...video,
    thumbnail: `https://i.ytimg.com/vi/${encodeURIComponent(video.id)}/mqdefault.jpg`,
  };
}

export async function searchYouTube(query: string, page = "") {
  const reply = await platform.invoke<{ videos: VideoResult[]; nextPage: string }>("youtube:search", {
    query,
    page,
  });
  return {
    ...reply,
    data: reply.data
      ? {
          videos: reply.data.videos.map(withThumbnail),
          nextPageToken: reply.data.nextPage || undefined,
        }
      : null,
  };
}

export function resolveChannel(input: string) {
  return platform.invoke<Subscription>("youtube:resolve", { input });
}

export async function subscriptionFeed(tokens: Record<string, string> = {}) {
  const reply = await platform.invoke<{
    videos: VideoResult[];
    nextPageTokens: Record<string, string>;
  }>("youtube:feed", { tokens });
  return {
    ...reply,
    data: reply.data ? { ...reply.data, videos: reply.data.videos.map(withThumbnail) } : null,
  };
}

export function addSubscription(input: string) {
  return platform.invoke<null>("youtube:addSubscription", { input });
}

export function removeSubscription(id: string) {
  return platform.invoke<null>("youtube:removeSubscription", { id });
}

export function subscriptions() {
  return platform.invoke<Subscription[]>("youtube:subscriptions");
}

export function saveYouTubeProgress(
  id: string,
  title: string,
  channel: string,
  seconds: number,
  duration: number,
) {
  return platform.invoke<null>("youtube:saveProgress", { id, title, channel, seconds, duration });
}

export function fetchTranscript(id: string, language = "ko") {
  return platform.invoke<unknown>("youtube:fetchTranscript", { id, language });
}

export function readTranscript(id: string) {
  return platform.invoke<unknown>("youtube:transcript", { id });
}

export function youtubeSettings() {
  return platform.invoke<YouTubeSettings>("youtube:settings");
}

export function saveYouTubeKey(key: string) {
  return platform.invoke<null>("youtube:saveKey", { key });
}

export function removeYouTubeKey() {
  return platform.invoke<null>("youtube:removeKey");
}
