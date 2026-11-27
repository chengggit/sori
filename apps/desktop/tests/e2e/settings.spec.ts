import { expect, test } from "@playwright/test";

test("settings page renders and switches theme", async ({ page }) => {
  await page.goto("/#/settings");
  await expect(page.getByTestId("page-title")).toHaveText("Settings");
  await expect(page.getByTestId("appearance-settings")).toBeVisible();
  await expect(page.getByTestId("dictionary-settings")).toBeVisible();
  await page.getByTestId("settings-theme-dark").click();
  await expect(page.locator("html")).toHaveClass(/dark/);
});
