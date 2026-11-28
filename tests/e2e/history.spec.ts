import { expect, test, type Page } from "@playwright/test";
async function seed(page: Page, mode = "normal") {
  await page.addInitScript(
    ({ mode }) => {
      (window as any).historyCalls = [];
      (window as any).historyMissing = false;
      (window as any).historyFail = mode === "error";
      (window as any).historySlowOpen = false;
      (window as any).historyPosition = 348;
      const local = (id: number, watchedAt: number | null) => ({
        id,
        title: "Take Charge of My Heart S01E03",
        displayTitle: "Take Charge of My Heart S01E03",
        seconds: (window as any).historyPosition,
        duration: 3873,
        watchedAt,
        thumbnailUrl: "file:///managed/thumbnail.jpg",
      });
      let listeners: ((payload: any) => void)[] = [];
      (window as any).emitHistoryChange = () =>
        listeners.forEach((fn) => fn({ name: "library-changed" }));
      (window as any).sori = {
        onEvent: (_name: string, fn: (payload: any) => void) => {
          listeners.push(fn);
          return () => (listeners = listeners.filter((item) => item !== fn));
        },
        invoke: async (channel: string, command: any, payload: any) => {
          const name = channel === "core:invoke" ? command : channel;
          const input = channel === "core:invoke" ? payload : command;
          (window as any).historyCalls.push({ name, payload: input });
          let data: any = null;
          if (name === "library:state") {
            if ((window as any).historyFail)
              return { ok: false, data: null, error: "Could not read the library database." };
            data = {
              documents: [],
              vocabulary: [],
              error: "",
              videos:
                mode === "empty"
                  ? [local(9, null)]
                  : [
                      local(1, 200),
                      local(9, null),
                      {
                        ...local(2, 300),
                        title: "한국 생활",
                        displayTitle: "한국 생활",
                        seconds: 0,
                        duration: 0,
                        thumbnailUrl: null,
                      },
                    ],
              youtubeHistory:
                mode === "empty"
                  ? []
                  : [
                      {
                        youtubeId: "abcdefghijk",
                        title: "한국 역사 이야기",
                        channel: "KBS 다큐",
                        seconds: 35,
                        duration: 600,
                        watchedAt: 250,
                        thumbnailUrl: "https://i.ytimg.com/vi/abcdefghijk/mqdefault.jpg",
                      },
                      {
                        youtubeId: "zeroprogr00",
                        title: "A watched video at the start",
                        channel: "",
                        seconds: 0,
                        duration: 0,
                        watchedAt: 100,
                        thumbnailUrl: null,
                      },
                    ],
            };
          }
          if (name === "library:state" && mode === "long")
            data.videos = Array.from({ length: 30 }, (_, index) => local(index + 1, 200 - index));
          if (name === "video:thumbnail")
            return { ok: false, data: null, error: "Thumbnail unavailable." };
          if (name === "video:read") {
            if ((window as any).historySlowOpen)
              await new Promise((resolve) => setTimeout(resolve, 300));
            if ((window as any).historyMissing)
              return { ok: false, data: null, error: "The original video was moved or removed." };
            data = { path: "/video.mp4", seconds: (window as any).historyPosition, sidecar: null };
          }
          if (name === "video:expose")
            return {
              id: "video",
              url: location.origin + "/missing-video.webm",
              name: "Take Charge of My Heart S01E03.webm",
            };
          if (name === "video:probe") return { tracks: [] };
          if (name === "video:readTranscript" || name === "youtube:transcript") data = {};
          if (name === "youtube:metadata") data = { title: "한국 역사 이야기", channel: "KBS 다큐" };
          if (name === "youtube:settings") data = { hasKey: false };
          if (name === "youtube:subscriptions") data = [];
          return { ok: true, data, error: "" };
        },
      };
      (window as any).YT = {
        Player: class {
          constructor(_frame: any, options: any) {
            setTimeout(() => options.events.onReady({ target: this }), 0);
          }
          getCurrentTime() {
            return 35;
          }
          getDuration() {
            return 600;
          }
          seekTo() {}
          destroy() {}
        },
      };
    },
    { mode },
  );
  await page.route("https://www.youtube.com/embed/**", (route) =>
    route.fulfill({ contentType: "text/html", body: "<p>YouTube fixture</p>" }),
  );
  await page.route("https://i.ytimg.com/**", (route) =>
    route.fulfill({
      contentType: "image/svg+xml",
      body: '<svg xmlns="http://www.w3.org/2000/svg" width="480" height="270"><rect width="480" height="270" fill="#d7dfc9"/><text x="240" y="142" text-anchor="middle" fill="#425936" font-size="26">한국어 · Korean</text></svg>',
    }),
  );
  await page.setViewportSize({ width: 1908, height: 1030 });
  await page.goto("/#/history");
}

test("History merges real watch records in timestamp order and displays progress offline", async ({
  page,
}) => {
  await seed(page);
  const rows = page.locator(".history-row");
  await expect(rows).toHaveCount(4);
  expect(
    await rows.evaluateAll((items) => items.map((item) => item.getAttribute("data-testid"))),
  ).toEqual([
    "history-local:2",
    "history-youtube:abcdefghijk",
    "history-local:1",
    "history-youtube:zeroprogr00",
  ]);
  await expect(rows.first()).toContainText("한국 생활");
  await expect(rows.last()).toContainText("Watched");
  await expect(page.getByTestId("history-local:1")).toContainText("5:48 / 1:04:33");
  await expect(page.getByTestId("history-local:1").getByRole("progressbar")).toHaveAttribute(
    "aria-valuenow",
    "9",
  );
  await expect(page.getByTestId("history-youtube:abcdefghijk").locator("img")).toHaveAttribute(
    "src",
    "https://i.ytimg.com/vi/abcdefghijk/mqdefault.jpg",
  );
  await expect(page.getByTestId("history-local:1").locator(".lucide-film")).toBeVisible();
  expect(
    await page.evaluate(() =>
      (window as any).historyCalls.some((c: any) => c.name === "video:thumbnail" && c.payload.id === 1),
    ),
  ).toBe(true);
  expect(
    await page.evaluate(() =>
      (window as any).historyCalls.some((c: any) => c.name.startsWith("youtube:")),
    ),
  ).toBe(false);
});

test("unplayed imports do not create history", async ({ page }) => {
  await seed(page, "empty");
  await expect(page.getByText("No watch history yet", { exact: true })).toBeVisible();
  await expect(page.locator(".history-row")).toHaveCount(0);
  await page.getByRole("link", { name: "Explore videos", exact: true }).click();
  await expect(page.getByTestId("explore-page")).toBeVisible();
});

test("History read errors remain distinct from empty history and recover without resets", async ({
  page,
}) => {
  await seed(page, "error");
  await expect(page.getByRole("alert")).toContainText("Could not read the library database.");
  await expect(page.getByText("No watch history yet", { exact: true })).toHaveCount(0);
  await page.evaluate(() => {
    (window as any).historyFail = false;
  });
  await page.getByRole("button", { name: "Retry", exact: true }).click();
  await expect(page.locator(".history-row")).toHaveCount(4);
  await expect(page.getByRole("alert")).toHaveCount(0);
});

test("missing local media preserves History and valid local links return to History", async ({
  page,
}) => {
  await seed(page);
  await page.evaluate(() => {
    (window as any).historyMissing = true;
  });
  await page.getByTestId("history-local:1").click();
  await expect(page.getByRole("alert")).toContainText("The original video was moved or removed.");
  await expect(page).toHaveURL(/#\/history$/);
  await expect(page.locator(".history-row")).toHaveCount(4);
  await page.evaluate(() => {
    (window as any).historyMissing = false;
  });
  await page.getByTestId("history-local:1").click();
  await expect(page).toHaveURL(/#\/watch\?id=1&from=history$/);
  await expect(page.getByTestId("watch-stage")).toBeVisible();
  await page.getByRole("button", { name: "Back", exact: true }).click();
  await expect(page).toHaveURL(/#\/history$/);
  await expect(page.locator(".history-row")).toHaveCount(4);
});

test("YouTube links return to History and late local checks cannot hijack navigation", async ({
  page,
}) => {
  await seed(page);
  await page.evaluate(() => {
    (window as any).historySlowOpen = true;
  });
  await page.getByTestId("history-local:1").click();
  await expect(page.getByRole("status")).toHaveText("Opening video…");
  await page.getByTestId("history-youtube:abcdefghijk").click();
  await expect(page).toHaveURL(/#\/watch\?v=abcdefghijk&from=history$/);
  await expect(page.getByTestId("youtube-player")).toBeVisible();
  await page.waitForTimeout(400);
  await expect(page).toHaveURL(/#\/watch\?v=abcdefghijk&from=history$/);
  await page.getByRole("button", { name: "Back", exact: true }).click();
  await expect(page).toHaveURL(/#\/history$/);
});

test("History reloads progress after mutation notifications and returning from Watch", async ({
  page,
}) => {
  await seed(page);
  await expect(page.getByTestId("history-local:1")).toContainText("5:48 / 1:04:33");
  await page.evaluate(() => {
    (window as any).historyPosition = 600;
    (window as any).emitHistoryChange();
  });
  await expect(page.getByTestId("history-local:1")).toContainText("10:00 / 1:04:33");
  await page.getByTestId("history-youtube:abcdefghijk").click();
  await page.evaluate(() => {
    (window as any).historyPosition = 900;
  });
  await page.getByRole("button", { name: "Back", exact: true }).click();
  await expect(page.getByTestId("history-local:1")).toContainText("15:00 / 1:04:33");
});

test("History visual baselines fit desktop, dark, narrow and keyboard focus", async ({ page }) => {
  await seed(page);
  await expect(page.locator(".history-row")).toHaveCount(4);
  await page.getByTestId("history-youtube:abcdefghijk").focus();
  await page.screenshot({ path: "test-results/history-baseline/light.png", animations: "disabled" });
  await page.evaluate(() => document.documentElement.classList.add("dark"));
  await page.screenshot({ path: "test-results/history-baseline/dark.png", animations: "disabled" });
  await page.setViewportSize({ width: 600, height: 800 });
  await page.screenshot({ path: "test-results/history-baseline/narrow.png", animations: "disabled" });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
  await page.keyboard.press("Control+Shift+Equal");
  await expect(page.locator("html")).toHaveCSS("zoom", "1.1");
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
});

test("History restores its list position after resuming an older video", async ({ page }) => {
  await seed(page, "long");
  const row = page.getByTestId("history-local:24");
  await row.scrollIntoViewIfNeeded();
  const scroller = page.getByTestId("page-content");
  await expect.poll(() => scroller.evaluate((el) => el.scrollTop)).toBeGreaterThan(2000);
  const before = await scroller.evaluate((el) => el.scrollTop);
  await row.click();
  await expect(page).toHaveURL(/#\/watch\?id=24&from=history$/);
  await page.getByRole("button", { name: "Back", exact: true }).click();
  await expect(page).toHaveURL(/#\/history$/);
  await expect.poll(() => scroller.evaluate((el) => el.scrollTop)).toBeCloseTo(before, 0);
});
