import type { VideoSummary, YouTubeHistoryEntry } from "$lib/library/commands";
import type { ResumeEntry } from "../home/resume";
import { watchLink } from "../home/resume";

export type HistoryEntry = ResumeEntry & { key: string; kind: "local" | "youtube" };

/** Both native timestamps are Unix seconds; unknown times sort last, never as now. */
export function historyEntries(local: VideoSummary[], youtube: YouTubeHistoryEntry[]): HistoryEntry[] {
  return [
    ...local
      .filter((item) => item.watchedAt != null)
      .map((item) => ({ ...item, kind: "local" as const, key: `local:${item.id}` })),
    ...youtube.map((item) => ({ ...item, kind: "youtube" as const, key: `youtube:${item.youtubeId}` })),
  ].sort((a, b) => (b.watchedAt ?? -Infinity) - (a.watchedAt ?? -Infinity));
}
export function historyLink(entry: HistoryEntry) {
  return `${watchLink(entry)}&from=history`;
}
export function historyThumbnail(entry: HistoryEntry) {
  return entry.kind === "youtube"
    ? `https://i.ytimg.com/vi/${encodeURIComponent(entry.youtubeId!)}/mqdefault.jpg`
    : entry.thumbnailUrl
      ? `sori-thumbnail://video/${entry.id}.jpg`
      : "";
}
