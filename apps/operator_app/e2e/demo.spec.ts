// SPDX-License-Identifier: Apache-2.0

import { expect, test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

const screenshotPath = path.resolve(
  __dirname,
  '../../../docs/demo.png',
);

test('criterion 15 demo flow', async ({ page }) => {
  const requests: string[] = [];
  page.on('request', (req) => {
    const url = req.url();
    if (!url.startsWith('http://127.0.0.1:4173')) {
      requests.push(url);
    }
  });

  await page.goto('/flutter-robot-operator/');
  await expect(page).toHaveTitle(/simulation only/i);

  await page.getByRole('button', { name: 'Load demo mission' }).click();
  await page.getByRole('button', { name: 'Start' }).click();
  await expect(page).toHaveTitle(/running/i, { timeout: 60_000 });

  fs.mkdirSync(path.dirname(screenshotPath), { recursive: true });
  await page.screenshot({ path: screenshotPath, fullPage: true });

  await page
    .getByRole('switch', { name: 'Simulate operator link loss' })
    .check();
  await expect(page.getByText('Deadman: true')).toBeVisible({
    timeout: 20_000,
  });
  await page
    .getByRole('switch', { name: 'Simulate operator link loss' })
    .uncheck();
  await page.waitForTimeout(500);

  await page.getByRole('button', { name: 'Resume' }).click();

  await page.getByRole('button', { name: 'E-STOP' }).click();
  await expect(page).toHaveTitle(/latched/i, { timeout: 15_000 });
  await expect(page.getByText(/Speed \(m\/s\): 0\.00/)).toBeVisible({
    timeout: 20_000,
  });

  await page.getByRole('button', { name: 'Reset' }).click();
  await page.getByRole('button', { name: 'Resume' }).click();

  await expect(page).toHaveTitle(/succeeded/i, { timeout: 180_000 });

  expect(requests).toEqual([]);
});
