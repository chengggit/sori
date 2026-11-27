import { expect, test } from "@playwright/test";

test("watch route renders its shell", async ({ page }) => {
  await page.goto("/#/watch?id=1");
  await expect(page.getByTestId("page-title")).toHaveText("Watch");
  await expect(page.getByTestId("watch-stage")).toBeVisible();
});
