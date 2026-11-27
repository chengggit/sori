import { expect, test } from "@playwright/test";

test("navigates pages and persists theme and zoom", async ({ page }) => {
  await page.goto("/#/library");
  await page.getByRole("button", { name: "Appearance", exact: true }).click();
  await page.getByTestId("theme-dark").click();
  await expect(page.locator("html")).toHaveClass(/dark/);
  await page.getByRole("slider", { name: "App zoom" }).focus();
  await page.keyboard.press("ArrowRight");
  await expect(page.locator("html")).toHaveCSS("zoom", "1.1");
  await page.keyboard.press("Escape");
  await page.getByTestId("nav-home").click();
  await expect(page.getByTestId("page-title")).toHaveText("Home");
  await page.reload();
  await expect(page.locator("html")).toHaveClass(/dark/);
  await expect(page.locator("html")).toHaveCSS("zoom", "1.1");
  await page.keyboard.press("Control+Shift+Digit0");
  await expect(page.locator("html")).toHaveCSS("zoom", "1");
  await page.getByRole("button", { name: "Appearance", exact: true }).click();
  await page.getByRole("slider", { name: "App zoom" }).focus();
  await page.keyboard.press("End");
  await page.getByTestId("theme-light").click();
  await expect(page.locator("html")).not.toHaveClass(/dark/);
  await page.keyboard.press("Escape");
  await expect(page.getByRole("button", { name: "Appearance", exact: true })).toBeFocused();
  await expect(page.getByTestId("nav-settings")).toBeInViewport();
});

test("desktop collapse persists and keyboard shortcut toggles navigation", async ({ page }) => {
  await page.goto("/#/library");
  await page.getByRole("button", { name: "Toggle Sidebar" }).click();
  await expect(page.locator('[data-slot="sidebar"]').first()).toHaveAttribute(
    "data-state",
    "collapsed",
  );
  await page.reload();
  await expect(page.locator('[data-slot="sidebar"]').first()).toHaveAttribute(
    "data-state",
    "collapsed",
  );
  await page.keyboard.press("Control+b");
  await expect(page.locator('[data-slot="sidebar"]').first()).toHaveAttribute("data-state", "expanded");
  await page.getByTestId("nav-library").focus();
  await page.keyboard.press("Enter");
  await expect(page.getByTestId("nav-library")).toHaveAttribute("aria-current", "page");
});

test("mobile navigation opens as a dialog and closes after navigation", async ({ page }) => {
  await page.setViewportSize({ width: 640, height: 720 });
  await page.goto("/#/vocabulary");
  const trigger = page.getByTestId("page-content").getByRole("button", { name: "Toggle Sidebar" });
  await trigger.click();
  await expect(page.getByRole("dialog", { name: "Sidebar" })).toBeVisible();
  await page.getByTestId("nav-library").click();
  await expect(page.getByRole("dialog", { name: "Sidebar" })).not.toBeVisible();
  await expect(page.getByTestId("page-title")).toHaveText("My Library");
  await trigger.click();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog", { name: "Sidebar" })).not.toBeVisible();
  await expect(trigger).toBeFocused();
});

test("changing document IDs remounts the reader and ignores a pending old load", async ({ page }) => {
  await page.addInitScript(() => {
    (window as any).sori = {
      invoke: async (_channel: string, command: string, payload: { id: number }) => {
        if (command === "document:read") {
          await new Promise((resolve) => setTimeout(resolve, payload.id === 1 ? 600 : 10));
          return {
            ok: true,
            data: { content: `Document ${payload.id}`, pdfPath: null, position: 0 },
            error: "",
          };
        }
        return { ok: true, data: [], error: "" };
      },
      onEvent: () => () => {},
    };
  });
  await page.goto("/#/reader?id=1");
  await page.evaluate(() => {
    location.hash = "#/reader?id=2";
  });
  await expect(page.getByTestId("reader-text")).toContainText("Document 2");
  await page.waitForTimeout(700);
  await expect(page.getByTestId("reader-text")).not.toContainText("Document 1");
  await expect(page.getByTestId("nav-library")).toHaveAttribute("aria-current", "page");
});

test("captures shell baselines in both themes and a narrow window", async ({ page }) => {
  await page.addInitScript(() => {
    (window as any).sori = {
      invoke: async () => ({
        ok: true,
        data: { documents: [], videos: [], vocabulary: [], youtubeHistory: [], error: "" },
        error: "",
      }),
      onEvent: () => () => {},
    };
  });
  await page.goto("/#/library");
  await page.screenshot({ path: "test-results/shell-baseline/light.png" });
  await page.getByRole("button", { name: "Appearance", exact: true }).click();
  await page.getByTestId("theme-dark").click();
  await page.keyboard.press("Escape");
  await expect(page.locator('[data-slot="sheet-content"]')).toHaveCount(0);
  await page.screenshot({ path: "test-results/shell-baseline/dark.png", animations: "disabled" });
  await page.setViewportSize({ width: 640, height: 720 });
  await page.getByRole("button", { name: "Toggle Sidebar" }).click();
  await page.screenshot({ path: "test-results/shell-baseline/mobile.png", animations: "disabled" });
});
