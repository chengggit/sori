import { expect, test } from '@playwright/test';

test('scaffold mounts and reports bridge state', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Sori' })).toBeVisible();
  await expect(page.getByTestId('status')).toHaveText(/bridge|pong/i);
});
