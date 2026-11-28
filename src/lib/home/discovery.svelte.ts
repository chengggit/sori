import { tick } from "svelte";
import {
  searchYouTube,
  subscriptionFeed,
  subscriptions,
  youtubeSettings,
  type YouTubeVideo,
  type Subscription,
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
  ready: Promise<void>;
  channels = $state<Subscription[]>([]);
  configured = $state(false);
  configurationError = $state("");
  channelsError = $state("");
  private configurationGeneration = 0;
  private alive = true;
  constructor() {
    this.ready = this.configure();
  }
  private async configure() {
    const generation = ++this.configurationGeneration;
    const [settings, channels] = await Promise.all([youtubeSettings(), subscriptions()]);
    if (!this.alive || generation !== this.configurationGeneration) return;
    this.hasKey = settings.data?.hasKey ?? false;
    if (channels.ok) this.channels = channels.data ?? [];
    this.configurationError = settings.ok ? "" : settings.error;
    this.channelsError = channels.ok ? "" : channels.error;
    this.configured = true;
  }
  refreshConfiguration() {
    this.ready = this.configure();
    return this.ready;
  }
  get hasMore() {
    return !!this.nextPage || Object.values(this.tokens).some(Boolean);
  }
  destroy() {
    this.generation++;
    this.configurationGeneration++;
    this.alive = false;
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
    if (this.configurationError || (!this.query && this.channelsError)) {
      this.error = this.configurationError || this.channelsError;
      this.loading = this.loadingMore = false;
      return;
    }
    if (!this.hasKey || (!this.query && !this.channels.length)) {
      this.notice = !this.hasKey
        ? "Add a YouTube API key in Settings to discover videos."
        : "Subscribe to channels to build your feed, or search YouTube.";
      this.videos = [];
      this.loading = this.loadingMore = false;
      return;
    }
    const requestedPage = append ? this.nextPage : "";
    const requestedTokens: Record<string, string> = append ? { ...this.tokens } : {};
    const reply = this.query
      ? await searchYouTube(this.query, requestedPage)
      : await subscriptionFeed(requestedTokens);
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
    this.nextPage = data.nextPageToken === requestedPage ? "" : (data.nextPageToken ?? "");
    this.tokens = Object.fromEntries(
      Object.entries(data.nextPageTokens ?? {}).filter(
        ([id, token]) => !!token && token !== requestedTokens[id],
      ),
    );
    if (!this.videos.length) this.notice = "No videos found.";
  }
}
