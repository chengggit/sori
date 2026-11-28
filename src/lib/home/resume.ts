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
  return item.youtubeId ? `#/explore?v=${encodeURIComponent(item.youtubeId)}` : `#/watch?id=${item.id}`;
}
export function formatTime(value: number) {
  const seconds = Math.max(0, Math.floor(value || 0));
  const minutes = Math.floor(seconds / 60);
  return seconds >= 3600
    ? `${Math.floor(minutes / 60)}:${String(minutes % 60).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`
    : `${minutes}:${String(seconds % 60).padStart(2, "0")}`;
}
