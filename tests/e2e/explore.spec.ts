import { expect, test, type Page } from "@playwright/test";

async function seed(page: Page, hasKey = true, channels = true) {
  await page.addInitScript(
    ({ hasKey, channels }) => {
      (window as any).exploreCalls = [];
      (window as any).failNextMore = false;
      (window as any).failAdd = false;
      (window as any).failRemove = false;
      let firstSearchError = true;
      let subscriptions = channels
        ? [
            { channelId: "UCone", title: "Korean Culture Podcast", uploadsPlaylistId: "UUone" },
            { channelId: "UCtwo", title: "KBS 다큐", uploadsPlaylistId: "UUtwo" },
          ]
        : [];
      const videos = Array.from({ length: 16 }, (_, i) => ({
        id: `abcdefgh${String(i).padStart(3, "0")}`,
        title: [
          "한국의 집들이 문화 · Korean housewarming",
          "젠틀몬스터 AI 안경?",
          "한국 역사 이야기",
          "우리 친구 가능?",
        ][i % 4],
        channel: i % 2 ? "KBS 다큐" : "Korean Culture Podcast",
      }));
      const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
      (window as any).sori = {
        onEvent: () => () => {},
        invoke: async (_channel: string, command: string, payload: any) => {
          (window as any).exploreCalls.push({ command, payload });
          let data: any = null;
          if (command === "youtube:settings") data = { hasKey, saved: hasKey };
          if (command === "youtube:subscriptions") data = subscriptions.map((item) => ({ ...item }));
          if (command === "youtube:search") {
            if (payload.query === "slow") await delay(450);
            if (payload.query === "offline" && firstSearchError) {
              firstSearchError = false;
              return {
                ok: false,
                data: null,
                error: "Couldn't reach YouTube. Check your connection and try again.",
              };
            }
            if (payload.page && (window as any).failNextMore) {
              (window as any).failNextMore = false;
              return { ok: false, data: null, error: "Could not load the next page." };
            }
            data = payload.page
              ? {
                  videos: [
                    videos[0],
                    { id: "newvideo001", title: "More Korean videos", channel: "KBS 다큐" },
                  ],
                  nextPage: payload.query === "repeat" ? payload.page : "",
                }
              : {
                  videos:
                    payload.query === "empty"
                      ? []
                      : payload.query === "fast"
                        ? [{ ...videos[0], title: "Fast result" }]
                        : videos,
                  nextPage: payload.query === "empty" ? "" : "page-2",
                };
          }
          if (command === "youtube:feed")
            data = {
              videos: payload.tokens?.UCtwo
                ? [videos[0], { id: "feedvideo01", title: "Older upload", channel: "KBS 다큐" }]
                : videos,
              nextPageTokens: payload.tokens?.UCtwo ? {} : { UCtwo: "feed-page-2" },
            };
          if (command === "youtube:addSubscription") {
            if ((window as any).failAdd) {
              (window as any).failAdd = false;
              return { ok: false, data: null, error: "Channel could not be resolved." };
            }
            subscriptions.push({
              channelId: "UCnew",
              title: "New channel",
              uploadsPlaylistId: "UUnew",
            });
          }
          if (command === "youtube:removeSubscription") {
            if ((window as any).failRemove) {
              (window as any).failRemove = false;
              return { ok: false, data: null, error: "Could not remove channel." };
            }
            subscriptions = subscriptions.filter((item) => item.channelId !== payload.id);
          }
          if (command === "library:state")
            data = { documents: [], videos: [], vocabulary: [], youtubeHistory: [] };
          if (command === "youtube:metadata") data = { title: "Sample video", channel: "KBS" };
          if (command === "video:readTranscript" || command === "youtube:transcript") data = {};
          return { ok: true, data, error: "" };
        },
      };
      (window as any).YT = {
        Player: class {
          constructor(_frame: any, options: any) {
            setTimeout(() => options.events.onReady({ target: this }), 0);
          }
          getCurrentTime() {
            return 0;
          }
          getDuration() {
            return 30;
          }
          seekTo() {}
          destroy() {}
        },
      };
    },
    { hasKey, channels },
  );
  await page.route("https://i.ytimg.com/**", (route) =>
    route.fulfill({
      contentType: "image/svg+xml",
      body: '<svg xmlns="http://www.w3.org/2000/svg" width="480" height="270"><rect width="480" height="270" fill="#d7dfc9"/><text x="240" y="142" text-anchor="middle" fill="#425936" font-size="26">한국어 · Korean</text></svg>',
    }),
  );
  await page.route("https://www.youtube.com/embed/**", (route) =>
    route.fulfill({ contentType: "text/html", body: "<p>YouTube player fixture</p>" }),
  );
  await page.setViewportSize({ width: 1908, height: 1030 });
  await page.goto("/#/explore");
  await expect(page.getByRole("button", { name: "Paste video link", exact: true })).toBeVisible();
}
async function search(page: Page, query: string) {
  const input = page.getByRole("textbox", { name: "Search YouTube", exact: true });
  await input.fill(query);
  await input.press("Enter");
}

test("Qt topics, shared cards, Watch links and return context", async ({ page }) => {
  await seed(page);
  await page.getByRole("button", { name: "History", exact: true }).click();
  await expect(page.locator(".video-card")).toHaveCount(16);
  await expect(page.getByRole("button", { name: "History", exact: true })).toHaveAttribute(
    "aria-pressed",
    "true",
  );
  expect(
    await page.evaluate(
      () => (window as any).exploreCalls.find((c: any) => c.command === "youtube:search").payload,
    ),
  ).toEqual({ query: "한국 역사 다큐 한국어 자막", page: "" });
  const first = page.locator(".video-card").first();
  const box = (await first.boundingBox())!;
  expect(box.width).toBeGreaterThan(340);
  await expect(first).toHaveAttribute("href", "#/watch?v=abcdefgh000&from=explore");
  await first.hover();
  await expect
    .poll(() => first.locator(".play-badge").evaluate((el) => getComputedStyle(el).transform))
    .toBe("matrix(1, 0, 0, 1, 0, 0)");
  await first.click();
  await expect(page.getByTestId("watch-title")).toHaveText("Sample video");
  await page.getByRole("button", { name: "Back", exact: true }).click();
  await expect(page).toHaveURL(/#\/explore$/);
  await expect(page.locator(".video-card")).toHaveCount(16);
  await expect(page.getByRole("button", { name: "History", exact: true })).toHaveAttribute(
    "aria-pressed",
    "true",
  );
});

test("new searches discard stale responses, and errors and empty results stay distinct", async ({
  page,
}) => {
  await seed(page);
  await search(page, "slow");
  await search(page, "fast");
  await expect(page.locator(".video-card h3")).toHaveText(["Fast result"]);
  await page.waitForTimeout(500);
  await expect(page.locator(".video-card h3")).toHaveText(["Fast result"]);
  await search(page, "offline");
  await expect(page.getByRole("alert")).toContainText("Couldn't reach YouTube");
  await page.getByRole("button", { name: "Retry", exact: true }).click();
  await expect(page.locator(".video-card")).toHaveCount(16);
  await expect(page.getByRole("alert")).toHaveCount(0);
  await search(page, "empty");
  await expect(page.getByRole("status")).toHaveText("No videos found.");
  await expect(page.locator(".video-card")).toHaveCount(0);
});

test("pagination appends unique videos, retains failures for retry and stops repeated tokens", async ({
  page,
}) => {
  await seed(page);
  await search(page, "repeat");
  await expect(page.locator(".video-card")).toHaveCount(16);
  await page.evaluate(() => {
    (window as any).failNextMore = true;
    (window as any).firstCard = document.querySelector(".video-card");
  });
  await page.getByRole("button", { name: "Load more", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText("Could not load the next page");
  await expect(page.locator(".video-card")).toHaveCount(16);
  await page.getByRole("button", { name: "Retry", exact: true }).click();
  await expect(page.locator(".video-card")).toHaveCount(17);
  await expect(page.getByRole("button", { name: "Load more", exact: true })).toHaveCount(0);
  expect(
    await page.evaluate(() => (window as any).firstCard === document.querySelector(".video-card")),
  ).toBe(true);
});

test("subscriptions add/remove failures retain entries, update the feed, and use per-channel pagination", async ({
  page,
}) => {
  await seed(page);
  await page.getByRole("button", { name: /^Subscriptions/ }).click();
  const dialog = page.getByRole("dialog");
  await expect(dialog).toContainText("Korean Culture Podcast");
  await page.evaluate(() => {
    (window as any).failAdd = true;
  });
  await dialog.getByRole("textbox", { name: "YouTube channel" }).fill("@new");
  await dialog.getByRole("button", { name: "Add channel", exact: true }).click();
  await expect(dialog.getByRole("alert")).toHaveText("Channel could not be resolved.");
  await expect(dialog.getByRole("textbox", { name: "YouTube channel" })).toHaveValue("@new");
  await dialog.getByRole("button", { name: "Add channel", exact: true }).click();
  await expect(dialog.getByText("New channel", { exact: true })).toBeVisible();
  await page.evaluate(() => {
    (window as any).failRemove = true;
  });
  await dialog.getByRole("button", { name: "Remove New channel", exact: true }).click();
  await expect(dialog.getByRole("alert")).toHaveText("Could not remove channel.");
  await expect(dialog.getByText("New channel", { exact: true })).toBeVisible();
  await dialog.getByRole("button", { name: "Remove New channel", exact: true }).click();
  await expect(dialog.getByText("New channel", { exact: true })).toHaveCount(0);
  await dialog.getByRole("button", { name: "View feed", exact: true }).click();
  await expect(page.locator(".video-card")).toHaveCount(16);
  await page.getByRole("button", { name: "Load more", exact: true }).click();
  await expect(page.locator(".video-card")).toHaveCount(17);
  expect(
    await page.evaluate(
      () =>
        (window as any).exploreCalls.filter((c: any) => c.command === "youtube:feed").at(-1).payload,
    ),
  ).toEqual({ tokens: { UCtwo: "feed-page-2" } });
});

test("empty subscriptions offer a real action and missing keys still allow pasted playback", async ({
  page,
}) => {
  await seed(page, true, false);
  await page.getByRole("button", { name: "Your feed", exact: true }).click();
  await expect(page.getByRole("status")).toContainText("Subscribe to channels");
  await page.getByRole("button", { name: "Add a channel", exact: true }).click();
  await expect(page.getByRole("dialog")).toContainText("No subscriptions yet.");
});

test("no key keeps topics disabled and the link dialog validates input without needing an API key", async ({
  page,
}) => {
  await seed(page, false);
  await expect(page.getByRole("status")).toContainText("Add a YouTube API key");
  await expect(page.getByRole("button", { name: "History", exact: true })).toBeDisabled();
  await page.getByRole("button", { name: "Paste video link", exact: true }).click();
  const input = page.getByRole("textbox", { name: "YouTube link", exact: true });
  await expect(input).toBeFocused();
  await input.fill("not a video");
  await input.press("Enter");
  await expect(page.getByRole("alert")).toHaveText("Paste a valid YouTube video link.");
  await input.fill("https://youtu.be/abcdefgh000");
  await input.press("Enter");
  await expect(page).toHaveURL(/#\/watch\?v=abcdefgh000&from=explore$/);
  await expect(page.getByTestId("youtube-player")).toBeVisible();
});

test("Explore visual baselines fit light, dark, narrow and zoomed layouts", async ({ page }) => {
  await seed(page);
  await page.getByRole("button", { name: "History", exact: true }).click();
  await expect(page.locator(".video-card")).toHaveCount(16);
  await page.screenshot({ path: "test-results/explore-baseline/light.png", animations: "disabled" });
  await page.getByRole("button", { name: /^Subscriptions/ }).click();
  await page.screenshot({
    path: "test-results/explore-baseline/subscriptions.png",
    animations: "disabled",
  });
  await page.keyboard.press("Escape");
  await page.evaluate(() => document.documentElement.classList.add("dark"));
  await page.screenshot({ path: "test-results/explore-baseline/dark.png", animations: "disabled" });
  await page.setViewportSize({ width: 650, height: 800 });
  await page.screenshot({ path: "test-results/explore-baseline/narrow.png", animations: "disabled" });
  await page.keyboard.press("Control+Shift+Equal");
  await expect(page.locator("html")).toHaveCSS("zoom", "1.1");
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
});
