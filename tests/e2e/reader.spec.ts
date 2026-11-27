import { expect, test } from '@playwright/test';

test('reader route renders its shell', async ({ page }) => {
  await page.goto('/#/reader?id=1');
  await expect(page.getByTestId('page-title')).toHaveText('Reader');
  await expect(page.getByText('Back to library')).toBeVisible();
});
