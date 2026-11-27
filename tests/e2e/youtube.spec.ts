import { expect, test } from "@playwright/test";

test("explore page renders YouTube controls", async ({ page }) => {
  await page.goto("/#/explore");
  await expect(page.getByTestId("page-title")).toHaveText("Explore");
  await expect(page.getByLabel("YouTube link")).toBeVisible();
  await expect(page.getByTestId("youtube-search")).toBeVisible();
  await expect(page.getByLabel("YouTube API key")).toBeVisible();
});
