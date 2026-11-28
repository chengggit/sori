import { Discovery } from "$lib/home/discovery.svelte";
import {
  addSubscription,
  removeSubscription,
  type YouTubeVideo,
  type Subscription,
} from "$lib/youtube/commands";

export type Selection = { kind: "search"; query: string; label: string } | { kind: "feed" };
type Snapshot = {
  selection: Selection;
  videos: YouTubeVideo[];
  query: string;
  nextPage: string;
  tokens: Record<string, string>;
  hasKey: boolean;
  channels: string;
  scroll: number;
  at: number;
};
let previous: Snapshot | undefined;

/** UI request state only; subscriptions, settings and network access stay in Rust. */
export class Explore {
  discovery = new Discovery();
  selection = $state<Selection | null>(null);
  channelInput = $state("");
  subscriptionError = $state("");
  changingSubscriptions = $state(false);
  restoreScroll = 0;
  private alive = true;
  async initialize() {
    await this.discovery.ready;
    if (!this.alive || !previous) return;
    const channels = this.discovery.channels
      .map((item) => item.channelId)
      .sort()
      .join(",");
    if (
      previous.hasKey !== this.discovery.hasKey ||
      Date.now() - previous.at > 15 * 60_000 ||
      (previous.selection.kind === "feed" && channels !== previous.channels)
    )
      return;
    this.selection = previous.selection;
    this.discovery.videos = previous.videos;
    this.discovery.query = previous.query;
    this.discovery.nextPage = previous.nextPage;
    this.discovery.tokens = previous.tokens;
    this.restoreScroll = previous.scroll;
  }
  destroy(scroll: number) {
    if (this.selection && !this.discovery.loading) {
      previous = {
        selection: { ...this.selection },
        videos: this.discovery.videos.map((video) => ({ ...video })),
        query: this.discovery.query,
        nextPage: this.discovery.nextPage,
        tokens: { ...this.discovery.tokens },
        hasKey: this.discovery.hasKey,
        channels: this.discovery.channels
          .map((item) => item.channelId)
          .sort()
          .join(","),
        scroll,
        at: Date.now(),
      };
    }
    this.alive = false;
    this.discovery.destroy();
  }
  browse(query: string, label = query) {
    const trimmed = query.trim();
    if (!trimmed) return Promise.resolve();
    this.selection = { kind: "search", query: trimmed, label };
    return this.discovery.load(trimmed);
  }
  feed() {
    this.selection = { kind: "feed" };
    return this.discovery.load("");
  }
  refresh() {
    return this.selection?.kind === "feed"
      ? this.feed()
      : this.selection
        ? this.browse(this.selection.query, this.selection.label)
        : Promise.resolve();
  }
  retry() {
    return this.discovery.videos.length && this.discovery.hasMore ? this.more() : this.refresh();
  }
  more() {
    if (
      !this.selection ||
      !this.discovery.hasMore ||
      this.discovery.loading ||
      this.discovery.loadingMore
    )
      return;
    return this.discovery.load(this.discovery.query, true);
  }
  async reloadConfiguration() {
    await this.discovery.refreshConfiguration();
    if (!this.alive) return;
    if (this.selection?.kind === "feed") await this.feed();
  }
  async addChannel() {
    if (this.changingSubscriptions || !this.discovery.hasKey || !this.channelInput.trim()) return;
    this.changingSubscriptions = true;
    this.subscriptionError = "";
    const reply = await addSubscription(this.channelInput.trim());
    if (!this.alive) return;
    if (!reply.ok) this.subscriptionError = reply.error;
    else {
      this.channelInput = "";
      await this.reloadConfiguration();
    }
    if (this.alive) this.changingSubscriptions = false;
  }
  async removeChannel(channel: Subscription) {
    if (this.changingSubscriptions) return;
    this.changingSubscriptions = true;
    this.subscriptionError = "";
    const reply = await removeSubscription(channel.channelId);
    if (!this.alive) return;
    if (!reply.ok) this.subscriptionError = reply.error;
    else await this.reloadConfiguration();
    if (this.alive) this.changingSubscriptions = false;
  }
}
