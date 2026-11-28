import { describe, it, expect } from "vitest";
import { historyEntries, historyLink, historyThumbnail } from "./entries";
import type { VideoSummary, YouTubeHistoryEntry } from "$lib/library/commands";
const local = (id: number, watchedAt: number | null, seconds = 10): VideoSummary => ({
  id,
  title: `Local ${id}`,
  displayTitle: `Local ${id}`,
  seconds,
  duration: 100,
  thumbnailUrl: "file:///managed/thumbnail.jpg",
  watchedAt,
});
const youtube = (id: string, watchedAt: number, seconds = 20): YouTubeHistoryEntry => ({
  youtubeId: id,
  title: id,
  channel: "Channel",
  seconds,
  duration: 100,
  watchedAt,
  thumbnailUrl: "https://i.ytimg.com/test.jpg",
});
describe("combined viewing history", () => {
  it("sorts native Unix timestamps together and excludes unplayed imports", () => {
    const entries = historyEntries(
      [local(1, null), local(2, 50), local(3, 30, 0)],
      [youtube("abcdefghijk", 40), youtube("zeroprogress", 20, 0)],
    );
    expect(entries.map((item) => item.key)).toEqual([
      "local:2",
      "youtube:abcdefghijk",
      "local:3",
      "youtube:zeroprogress",
    ]);
    expect(entries[2].seconds).toBe(0);
    expect(historyEntries([local(1, null)], [])).toEqual([]);
  });
  it("keeps same-second ordering stable and preserves source identity in links/artwork", () => {
    const entries = historyEntries([local(2, 50), local(1, 50)], [youtube("abcdefghijk", 50)]);
    expect(entries.map((item) => item.key)).toEqual(["local:2", "local:1", "youtube:abcdefghijk"]);
    expect(historyLink(entries[0])).toBe("#/watch?id=2&from=history");
    expect(historyLink(entries[2])).toBe("#/watch?v=abcdefghijk&from=history");
    expect(historyThumbnail(entries[0])).toBe("sori-thumbnail://video/2.jpg");
    expect(historyThumbnail(entries[2])).toBe("https://i.ytimg.com/vi/abcdefghijk/mqdefault.jpg");
  });
});
