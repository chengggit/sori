import { expect, test } from "@playwright/test";

test("Explore exposes bridge errors without disabling link entry", async ({ page }) => {
  await page.goto("/#/explore");
  await expect(page.getByTestId("page-title")).toHaveText("Explore");
  await expect(page.getByRole("alert")).toContainText("Desktop bridge unavailable");
  await expect(page.getByRole("button", { name: "Retry settings", exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Paste video link", exact: true }).click();
  await expect(page.getByLabel("YouTube link")).toBeVisible();
});
