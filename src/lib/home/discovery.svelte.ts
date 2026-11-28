import { tick } from "svelte";
import {
  searchYouTube,
  subscriptionFeed,
  subscriptions,
  youtubeSettings,
  type YouTubeVideo,
} from "../youtube/commands";

/** One owner for feed/search requests; obsolete replies never replace current results. */
export class Discovery {
  videos = $state<YouTubeVideo[]>([]);
  loading = $state(false);
  loadingMore = $state(false);
  error = $state("");
  notice = $state("");
  query = $state("");
  hasKey = $state(false);
  nextPage = $state("");
  tokens = $state<Record<string, string>>({});
  private generation = 0;
  private ready: Promise<void>;
  private channelCount = 0;
  constructor() {
    this.ready = this.configure();
  }
  private async configure() {
    const [settings, channels] = await Promise.all([youtubeSettings(), subscriptions()]);
    this.hasKey = settings.data?.hasKey ?? false;
    this.channelCount = channels.data?.length ?? 0;
    if (!settings.ok || !channels.ok) this.error = settings.error || channels.error;
  }
  get hasMore() {
    return !!this.nextPage || Object.values(this.tokens).some(Boolean);
  }
  destroy() {
    this.generation++;
  }
  async load(query = "", append = false) {
    const generation = ++this.generation;
    const started = Date.now();
    const nextQuery = query.trim();
    if (!append) {
      if (nextQuery !== this.query) this.videos = [];
      this.nextPage = "";
      this.tokens = {};
    }
    this.query = nextQuery;
    this.error = "";
    this.notice = "";
    this.loading = !append;
    this.loadingMore = append;
    // Flush the busy state before a fast reply can clear it, so the spinner is visible.
    await tick();
    await this.ready;
    if (generation !== this.generation) return;
    if (!this.hasKey || (!this.query && !this.channelCount)) {
      this.notice = !this.hasKey
        ? "Add a YouTube API key in Settings to discover videos."
        : "Subscribe to channels in Explore to build your feed, or search YouTube above.";
      this.videos = [];
      this.loading = this.loadingMore = false;
      return;
    }
    const reply = this.query
      ? await searchYouTube(this.query, append ? this.nextPage : "")
      : await subscriptionFeed(append ? this.tokens : {});
    if (generation !== this.generation) return;
    // Keep the spinner up briefly so quick refreshes still show feedback.
    const remaining = 320 - (Date.now() - started);
    if (remaining > 0) await new Promise((resolve) => setTimeout(resolve, remaining));
    if (generation !== this.generation) return;
    this.loading = this.loadingMore = false;
    if (!reply.ok || !reply.data) {
      this.error = reply.error || "Could not load videos. Try again.";
      return;
    }
    const data = reply.data as {
      videos: YouTubeVideo[];
      nextPageToken?: string;
      nextPageTokens?: Record<string, string>;
    };
    const seen = new Set<string>();
    this.videos = [...(append ? this.videos : []), ...data.videos].filter(
      (video) => !seen.has(video.id) && !!seen.add(video.id),
    );
    this.nextPage = data.nextPageToken ?? "";
    this.tokens = data.nextPageTokens ?? {};
    if (!this.videos.length) this.notice = "No videos found.";
  }
}
