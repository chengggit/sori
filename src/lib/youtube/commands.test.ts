import { beforeEach, expect, it, vi } from "vitest";
vi.mock("../../platform", () => ({ platform: { invoke: vi.fn() } }));
import { platform } from "../../platform";
import { searchYouTube, subscriptionFeed } from "./commands";
const invoke = vi.mocked(platform.invoke);
beforeEach(() => invoke.mockReset());

it("adapts the Rust SearchPage shape into artwork and a usable next-page token", async () => {
  invoke.mockResolvedValue({
    ok: true,
    data: {
      videos: [{ id: "abcdefghijk", title: "Korean", channel: "Channel" }],
      nextPage: "page-two",
    },
    error: "",
  });
  const reply = await searchYouTube("Korean");
  expect(reply.data?.videos[0].thumbnail).toBe("https://i.ytimg.com/vi/abcdefghijk/mqdefault.jpg");
  expect(reply.data?.nextPageToken).toBe("page-two");
  await searchYouTube("Korean", reply.data?.nextPageToken);
  expect(invoke).toHaveBeenLastCalledWith("youtube:search", { query: "Korean", page: "page-two" });
});

it("derives feed artwork from Rust FeedVideo IDs and retains pagination and metadata", async () => {
  invoke.mockResolvedValue({
    ok: true,
    data: {
      videos: [{ id: "abcdefghijk", title: "Korean", channel: "Channel", publishedAt: "2026-11-28" }],
      nextPageTokens: { channel: "next" },
    },
    error: "",
  });
  const reply = await subscriptionFeed();
  expect(reply.data?.videos[0]).toMatchObject({
    thumbnail: "https://i.ytimg.com/vi/abcdefghijk/mqdefault.jpg",
    publishedAt: "2026-11-28",
  });
  expect(reply.data?.nextPageTokens).toEqual({ channel: "next" });
});

it("preserves failures without manufacturing successful results", async () => {
  invoke.mockResolvedValue({ ok: false, data: null, error: "Offline" });
  expect(await searchYouTube("Korean")).toEqual({ ok: false, data: null, error: "Offline" });
  expect(await subscriptionFeed()).toEqual({ ok: false, data: null, error: "Offline" });
});
