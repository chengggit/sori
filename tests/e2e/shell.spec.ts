import { expect, test } from '@playwright/test';

test('navigates pages in both themes', async ({ page }) => {
  await page.goto('/#/library');
  await expect(page.getByTestId('page-title')).toHaveText('My Library');

  await page.getByTestId('theme-dark').click();
  await expect(page.locator('html')).toHaveClass(/dark/);
  await expect(page.getByTestId('theme-state')).toHaveText('Dark');

  await page.getByTestId('nav-home').click();
  await expect(page.getByTestId('page-title')).toHaveText('Home');
  await expect(page).toHaveURL(/#\/home$/);

  await page.getByTestId('theme-light').click();
  await expect(page.locator('html')).not.toHaveClass(/dark/);
  await expect(page.getByTestId('theme-state')).toHaveText('Light');
});

test('collapses navigation at narrow widths', async ({ page }) => {
  await page.setViewportSize({ width: 640, height: 720 });
  await page.goto('/#/vocabulary');
  await expect(page.getByTestId('page-title')).toHaveText('Vocabulary');
  const width = await page.getByTestId('sidebar').evaluate((node) => node.clientWidth);
  expect(width).toBeLessThanOrEqual(56);
});
