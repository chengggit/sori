import { expect, test, type Locator } from "@playwright/test";

async function singleFieldEdge(field: Locator) {
  const before = await field.boundingBox();
  await field.focus();
  await expect(field).toBeFocused();
  await expect.poll(() => field.evaluate((node) => getComputedStyle(node).outlineStyle)).toBe("none");
  await expect
    .poll(() => field.evaluate((node) => getComputedStyle(node).boxShadow))
    .toContain("inset");
  const after = await field.boundingBox();
  expect(after?.width).toBe(before?.width);
  expect(after?.height).toBe(before?.height);
}

for (const theme of ["light", "dark"] as const) {
  test(`text fields have one focus edge and keyboard navigation stays visible in ${theme} mode`, async ({
    page,
  }) => {
    await page.goto("/#/settings");
    await page.getByTestId(`settings-theme-${theme}`).click();
    await singleFieldEdge(page.getByRole("combobox", { name: "Reading font" }));
    await page.getByTestId("nav-home").click();
    await singleFieldEdge(page.getByRole("textbox", { name: "Search YouTube", exact: true }));
    await page.getByTestId("nav-library").click();
    await singleFieldEdge(page.getByRole("textbox", { name: "Search your library" }));
    await page.getByTestId("import-text").click();
    await singleFieldEdge(page.getByRole("textbox", { name: "Title", exact: true }));
    await page.screenshot({ path: `test-results/focus-baseline/${theme}.png`, animations: "disabled" });
    await singleFieldEdge(page.getByRole("textbox", { name: "Text", exact: true }));
    await page.keyboard.press("Escape");
    const button = page.getByTestId("import-text");
    await button.focus();
    await expect(button).toHaveCSS("outline-style", "solid");
    await expect(button).toHaveCSS("outline-width", "2px");
  });
}
