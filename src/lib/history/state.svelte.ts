import {
  loadLibraryState,
  readVideo,
  type VideoSummary,
  type YouTubeHistoryEntry,
} from "$lib/library/commands";
import { platform } from "../../platform";
import { historyEntries, historyLink, type HistoryEntry } from "./entries";

export class HistoryModel {
  local = $state<VideoSummary[]>([]);
  youtube = $state<YouTubeHistoryEntry[]>([]);
  loading = $state(true);
  refreshing = $state(false);
  error = $state("");
  openError = $state("");
  opening = $state("");
  artworkVersions = $state<Record<number, number>>({});
  private active = true;
  private generation = 0;
  private openingGeneration = 0;
  private attempted = new Set<number>();
  private queue: number[] = [];
  private preparing = false;
  get entries() {
    return historyEntries(this.local, this.youtube);
  }
  destroy() {
    this.active = false;
    this.generation++;
    this.openingGeneration++;
    this.queue = [];
  }
  async load() {
    const generation = ++this.generation;
    this.refreshing = true;
    const reply = await loadLibraryState();
    if (!this.active || generation !== this.generation) return;
    this.loading = false;
    this.refreshing = false;
    if (!reply.ok || !reply.data) {
      this.error = reply.error || "Could not load watch history.";
      return;
    }
    this.local = reply.data.videos ?? [];
    this.youtube = reply.data.youtubeHistory ?? [];
    this.error = reply.data.error || "";
  }
  requestThumbnail(entry: HistoryEntry, force = false) {
    if (
      entry.kind !== "local" ||
      !entry.id ||
      (!force && entry.thumbnailUrl && entry.duration > 0) ||
      this.attempted.has(entry.id)
    )
      return;
    this.attempted.add(entry.id);
    this.queue.push(entry.id);
    void this.prepareThumbnails();
  }
  private async prepareThumbnails() {
    if (this.preparing) return;
    this.preparing = true;
    try {
      while (this.active && this.queue.length) {
        const id = this.queue.shift()!;
        if (!this.local.some((item) => item.id === id && item.watchedAt != null)) continue;
        const reply = await platform.invoke<VideoSummary>("video:thumbnail", { id });
        if (!this.active) return;
        if (reply.ok && reply.data?.id === id) {
          const metadata = reply.data;
          // Enrichment must not overwrite newer progress received during the job.
          this.local = this.local.map((item) =>
            item.id === id
              ? { ...item, duration: metadata.duration, thumbnailUrl: metadata.thumbnailUrl }
              : item,
          );
          this.artworkVersions[id] = (this.artworkVersions[id] ?? 0) + 1;
        }
      }
    } finally {
      this.preparing = false;
    }
  }
  async open(entry: HistoryEntry) {
    const generation = ++this.openingGeneration;
    this.openError = "";
    this.opening = entry.key;
    if (entry.kind === "local") {
      const reply = await readVideo(entry.id!);
      if (!this.active || generation !== this.openingGeneration) return;
      if (!reply.ok) {
        this.openError = reply.error || "Could not open this video.";
        this.opening = "";
        return;
      }
    }
    if (!this.active || generation !== this.openingGeneration) return;
    this.opening = "";
    return historyLink(entry);
  }
}
