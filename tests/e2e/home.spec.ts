import { expect, test, type Page } from "@playwright/test";

async function seed(page: Page, hasKey = true) {
  await page.addInitScript(
    ({ hasKey }) => {
      const titles = [
        "한국의 집들이 문화 · Korean housewarming",
        "젠틀몬스터 AI 안경?",
        "한국 일상 인터뷰",
        "우리 친구 가능?",
        "최고의 생일 선물은?",
        "집콕 · 비 오는 날",
        "함께하는 한국 생활",
        "한국어로 이야기해요",
      ];
      const videos = titles.map((title, index) => ({
        id: `abcdefghij${index}`,
        title,
        channel: index % 2 ? "한국 일상" : "Korean Culture Podcast",
      }));
      (window as any).homeRequests = [];
      (window as any).sori = {
        invoke: async (_channel: string, command: string, payload: any) => {
          (window as any).homeRequests.push({ command, payload });
          let data: any = null;
          if (command === "library:state")
            data = {
              documents: [],
              videos: [
                {
                  id: 3,
                  title: "Take Charge of My Heart S01E03",
                  seconds: 348,
                  duration: 3873,
                  watchedAt: 100,
                },
              ],
              vocabulary: [],
              youtubeHistory: [],
              error: "",
            };
          if (command === "youtube:settings") data = { hasKey, saved: hasKey };
          if (command === "youtube:subscriptions")
            data = [{ channelId: "channel", title: "Korean culture" }];
          if (command === "youtube:feed")
            data = { videos, nextPageTokens: payload.tokens?.channel ? {} : { channel: "next" } };
          if (command === "youtube:search") {
            await new Promise((resolve) => setTimeout(resolve, payload.query === "slow" ? 400 : 10));
            if (payload.query === "error")
              return { ok: false, data: null, error: "YouTube is unavailable. Try again." };
            data = { videos: [{ ...videos[0], title: payload.query }], nextPageToken: "" };
          }
          if (command === "youtube:metadata") data = { title: "Pasted video", channel: "Channel" };
          if (command === "video:thumbnail") return { ok: false, data: null, error: "No thumbnail" };
          return { ok: true, data, error: "" };
        },
        onEvent: () => () => {},
      };
    },
    { hasKey },
  );
  await page.route("https://i.ytimg.com/**", async (route) => {
    await route.fulfill({
      contentType: "image/svg+xml",
      body: '<svg xmlns="http://www.w3.org/2000/svg" width="480" height="270"><rect width="480" height="270" fill="#d7dfc9"/><text x="240" y="142" text-anchor="middle" fill="#425936" font-size="26">한국어 · Korean</text></svg>',
    });
  });
}

test("home shows stored progress, subscription videos, and deduplicated pagination", async ({
  page,
}) => {
  await seed(page);
  await page.goto("/#/home");
  await expect(page.getByTestId("resume-card")).toContainText("5:48 / 1:04:33");
  await expect(page.getByRole("link", { name: "Resume" })).toHaveAttribute("href", "#/watch?id=3");
  await expect(page.locator(".video-card")).toHaveCount(8);
  await expect(page.locator(".video-card img").first()).toHaveAttribute(
    "src",
    "https://i.ytimg.com/vi/abcdefghij0/mqdefault.jpg",
  );
  await expect
    .poll(() =>
      page
        .locator(".video-card img")
        .first()
        .evaluate((img: HTMLImageElement) => img.naturalWidth),
    )
    .toBeGreaterThan(0);
  await page.getByRole("button", { name: "Load more" }).click();
  await expect(page.getByRole("button", { name: "Load more" })).toHaveCount(0);
  await expect(page.locator(".video-card")).toHaveCount(8);
});

test("search discards obsolete responses and exposes recoverable errors", async ({ page }) => {
  await seed(page);
  await page.goto("/#/home");
  const input = page.getByRole("textbox", { name: "Search YouTube", exact: true });
  await input.fill("slow");
  await input.press("Enter");
  await input.fill("fast");
  await input.press("Enter");
  await expect(page.locator(".video-card h3")).toHaveText(["fast"]);
  await page.waitForTimeout(450);
  await expect(page.locator(".video-card h3")).toHaveText(["fast"]);
  await input.fill("error");
  await input.press("Enter");
  await expect(page.getByRole("alert")).toContainText("YouTube is unavailable");
  await input.fill("recovered");
  await input.press("Enter");
  await expect(page.locator(".video-card h3")).toHaveText(["recovered"]);
});

test("without an API key, local resume and valid pasted links remain available", async ({ page }) => {
  await seed(page, false);
  await page.goto("/#/home");
  await expect(page.getByRole("status")).toContainText("Add a YouTube API key");
  await expect(page.getByRole("link", { name: "Resume" })).toBeVisible();
  await page.getByRole("button", { name: "Paste YouTube link" }).click();
  await page.getByRole("textbox", { name: "YouTube link", exact: true }).fill("invalid");
  await page.getByRole("button", { name: "Open video", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText("valid YouTube");
  await page
    .getByRole("textbox", { name: "YouTube link", exact: true })
    .fill("https://youtu.be/abcdefghij0");
  await page.getByRole("button", { name: "Open video", exact: true }).click();
  await expect(page).toHaveURL(/#\/explore\?v=abcdefghij0$/);
  await expect(page.getByTestId("youtube-player")).toBeVisible();
});

test("home visual baselines fit desktop, dark mode and narrow windows", async ({ page }) => {
  await seed(page);
  await page.setViewportSize({ width: 1908, height: 1030 });
  await page.goto("/#/home");
  await expect(page.locator(".video-card")).toHaveCount(8);
  await page.screenshot({ path: "test-results/home-baseline/light.png", animations: "disabled" });
  await page.getByRole("button", { name: "Appearance", exact: true }).click();
  await page.getByTestId("theme-dark").click();
  await page.keyboard.press("Escape");
  await expect(page.locator('[data-slot="sheet-content"]')).toHaveCount(0);
  await page.screenshot({ path: "test-results/home-baseline/dark.png", animations: "disabled" });
  await page.setViewportSize({ width: 640, height: 720 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: "test-results/home-baseline/mobile.png", animations: "disabled" });
});
