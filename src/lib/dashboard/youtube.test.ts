import { describe, expect, it } from "vitest";
import {
  parseIsoDuration,
  parseYouTubeLink,
  parseYouTubeMetadata,
  parseYouTubeSearch,
  youtubeSearchError,
} from "./youtube";

describe("YouTube parsing", () => {
  it("accepts watch, short, live, embed and youtu.be links", () => {
    expect(parseYouTubeLink("https://www.youtube.com/watch?v=dQw4w9WgXcQ")).toBe("dQw4w9WgXcQ");
    expect(parseYouTubeLink("https://youtu.be/dQw4w9WgXcQ")).toBe("dQw4w9WgXcQ");
    expect(parseYouTubeLink("https://www.youtube.com/shorts/dQw4w9WgXcQ")).toBe("dQw4w9WgXcQ");
    expect(parseYouTubeLink("https://example.com/watch?v=dQw4w9WgXcQ")).toBeNull();
  });

  it("parses ISO-8601 durations", () => {
    expect(parseIsoDuration("PT1H2M3S")).toBe(3723);
    expect(parseIsoDuration("P1DT2S")).toBe(86402);
    expect(parseIsoDuration("nonsense")).toBeUndefined();
  });

  it("parses oembed metadata and search pages", () => {
    expect(parseYouTubeMetadata({ title: " 제목 ", author_name: "채널" })).toEqual({
      title: "제목",
      channel: "채널",
    });
    const page = parseYouTubeSearch({
      items: [
        {
          id: { videoId: "dQw4w9WgXcQ" },
          snippet: {
            title: "Video",
            channelTitle: "Channel",
            thumbnails: { default: { url: "https://img.example/a.jpg" } },
          },
        },
      ],
      nextPageToken: "next",
    });
    expect(page.videos[0]).toMatchObject({ id: "dQw4w9WgXcQ", thumbnail: "https://img.example/a.jpg" });
    expect(page.nextPageToken).toBe("next");
  });

  it("maps API failures without echoing server text", () => {
    expect(youtubeSearchError(403, "quotaExceeded")).toMatch(/quota/i);
    expect(youtubeSearchError(429)).toMatch(/limiting/i);
    expect(youtubeSearchError(200)).toBeNull();
  });
});
