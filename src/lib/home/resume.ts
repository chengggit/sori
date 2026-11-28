export type ResumeEntry = {
  id?: number;
  youtubeId?: string;
  title: string;
  displayTitle?: string;
  channel?: string;
  seconds: number;
  duration: number;
  watchedAt?: number | null;
  thumbnailUrl?: string | null;
};
export function recentVideo(local: ResumeEntry[], youtube: ResumeEntry[]): ResumeEntry | undefined {
  return [
    ...local.filter((item) => item.watchedAt != null),
    ...youtube.filter((item) => item.seconds > 0),
  ].sort((a, b) => (b.watchedAt ?? 0) - (a.watchedAt ?? 0))[0];
}
export function watchLink(item: ResumeEntry) {
  return item.youtubeId ? `#/watch?v=${encodeURIComponent(item.youtubeId)}` : `#/watch?id=${item.id}`;
}
export { formatTime } from "../video/time";
