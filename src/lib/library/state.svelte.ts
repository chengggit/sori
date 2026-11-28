import { platform } from "../../platform";
import { loadLibraryState, type DocumentSummary, type VideoSummary } from "./commands";

/** Library refresh and thumbnail work outlive individual cards, not the page. */
export class LibraryModel {
  documents = $state<DocumentSummary[]>([]);
  videos = $state<VideoSummary[]>([]);
  loading = $state(true);
  busy = $state(false);
  error = $state("");
  private active = true;
  private generation = 0;
  private preparing = false;
  private attempted = new Set<number>();
  dispose() {
    this.active = false;
    this.generation++;
  }
  async load() {
    const generation = ++this.generation;
    const reply = await loadLibraryState();
    if (!this.active || generation !== this.generation) return;
    this.loading = false;
    if (!reply.ok || !reply.data) {
      this.error = reply.error || "Could not load your library.";
      return;
    }
    this.documents = reply.data.documents;
    this.videos = reply.data.videos;
    this.error = reply.data.error;
    void this.prepareThumbnails();
  }
  private async prepareThumbnails() {
    if (this.preparing) return;
    this.preparing = true;
    try {
      while (this.active) {
        const video = this.videos.find(
          (item) => (!item.thumbnailUrl || !item.duration) && !this.attempted.has(item.id),
        );
        if (!video) break;
        this.attempted.add(video.id);
        const reply = await platform.invoke<VideoSummary>("video:thumbnail", { id: video.id });
        if (this.active && reply.ok && reply.data) {
          const data = reply.data;
          this.videos = this.videos.map((item) => (item.id === data.id ? data : item));
        }
      }
    } finally {
      this.preparing = false;
    }
  }
  async run(action: () => Promise<{ ok: boolean; error: string }>) {
    if (this.busy) return false;
    this.busy = true;
    this.error = "";
    try {
      const reply = await action();
      if (!reply.ok) {
        this.error = reply.error;
        return false;
      }
      await this.load();
      return true;
    } catch (cause) {
      this.error = cause instanceof Error ? cause.message : String(cause);
      return false;
    } finally {
      this.busy = false;
    }
  }
}
