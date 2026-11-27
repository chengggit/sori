import { expect, test } from '@playwright/test';

test('app shell mounts with navigation', async ({ page }) => {
  await page.goto('/#/home');
  await expect(page.getByTestId('page-title')).toHaveText('Home');
  await expect(page.getByTestId('sidebar')).toBeVisible();
  await expect(page.getByTestId('nav-library')).toBeVisible();
});
