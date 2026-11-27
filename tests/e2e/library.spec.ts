import { expect, test } from '@playwright/test';

test('library page renders import controls and empty state', async ({ page }) => {
  await page.goto('/#/library');
  await expect(page.getByTestId('page-title')).toHaveText('My Library');
  await expect(page.getByTestId('import-text')).toBeVisible();
  await expect(page.getByTestId('empty-texts')).toHaveText('No texts yet');
});
