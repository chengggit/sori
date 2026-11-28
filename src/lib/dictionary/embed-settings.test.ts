import { afterEach, expect, it, vi } from "vitest";
import { get } from "svelte/store";
import { embedSettings, loadEmbedSettings } from "./embed-settings";
afterEach(() => vi.unstubAllGlobals());
it("restores saved dictionary order, preserves KRDict and filters invalid providers", () => {
  let stored = JSON.stringify({
    enabled: ["papago", "naver", "krdict", "custom-one", "papago", "unknown"],
    custom: [
      { id: "custom-one", url: "https://example.com/{word}" },
      { id: "custom-bad", url: "http://example.com/{word}" },
    ],
  });
  vi.stubGlobal("localStorage", {
    getItem: () => stored,
    setItem: (_key: string, value: string) => {
      stored = value;
    },
  });
  const stop = loadEmbedSettings();
  expect(get(embedSettings).enabled).toEqual(["papago", "naver-ko", "krdict", "custom-one"]);
  expect(get(embedSettings).custom).toHaveLength(1);
  stop();
});
