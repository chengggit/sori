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

export function searchYouTube(query: string, page = "") {
  return platform.invoke<YouTubeSearchPage>("youtube:search", { query, page });
}

export function resolveChannel(input: string) {
  return platform.invoke<Subscription>("youtube:resolve", { input });
}

export function subscriptionFeed(tokens: Record<string, string> = {}) {
  return platform.invoke<{ videos: YouTubeVideo[]; nextPageTokens: Record<string, string> }>(
    "youtube:feed",
    { tokens },
  );
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
