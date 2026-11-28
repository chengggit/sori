import { describe, expect, it } from "vitest";
import { formatTime, recentVideo, watchLink } from "./resume";
describe("continue watching", () => {
  it("chooses the newest watched source, ignoring unplayed imports", () => {
    const local = { id: 1, title: "Local", seconds: 10, duration: 100, watchedAt: 12 };
    const youtube = {
      youtubeId: "abcdefghijk",
      title: "YouTube",
      seconds: 20,
      duration: 100,
      watchedAt: 15,
    };
    expect(recentVideo([{ ...local, watchedAt: null }, local], [youtube])).toEqual(youtube);
    expect(recentVideo([local], [{ ...youtube, seconds: 0 }])).toEqual(local);
    expect(recentVideo([{ ...local, watchedAt: null }], [])).toBeUndefined();
    expect(watchLink(local)).toBe("#/watch?id=1");
    expect(watchLink(youtube)).toBe("#/explore?v=abcdefghijk");
  });
  it("formats long video positions", () => {
    expect(formatTime(348)).toBe("5:48");
    expect(formatTime(3873)).toBe("1:04:33");
  });
});
