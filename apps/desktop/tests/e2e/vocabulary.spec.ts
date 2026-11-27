import { expect, test } from '@playwright/test';

test('vocabulary page renders filters and empty state', async ({ page }) => {
  await page.goto('/#/vocabulary');
  await expect(page.getByTestId('page-title')).toHaveText('Vocabulary');
  await expect(page.getByLabel('Search vocabulary')).toBeVisible();
  await expect(page.getByTestId('empty-vocabulary')).toHaveText('No saved words yet');
});
