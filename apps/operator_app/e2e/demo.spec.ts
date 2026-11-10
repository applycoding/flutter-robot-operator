// SPDX-License-Identifier: Apache-2.0

import { expect, test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

const screenshotPath = path.resolve(
  __dirname,
  '../../../docs/demo.png',
);

function pngDimensions(filePath: string): { width: number; height: number } {
  const buf = fs.readFileSync(filePath);
  return {
    width: buf.readUInt32BE(16),
    height: buf.readUInt32BE(20),
  };
}

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
  await expect(
    page.getByText(
      'Simulation only. Not connected to a robot. Not a certified safety system.',
    ),
  ).toBeVisible();

  await expect
    .poll(
      async () => {
        const title = await page.title();
        if (!/running/i.test(title)) {
          return false;
        }
        const body = await page.locator('body').innerText();
        const wpMatch = body.match(/Waypoint index:\s*(\d+)/);
        const tickMatch = body.match(/Mission tick:\s*(\d+)/);
        const wp = wpMatch ? Number(wpMatch[1]) : -1;
        const tick = tickMatch ? Number(tickMatch[1]) : -1;
        return wp >= 1 || tick >= 250;
      },
      { timeout: 120_000 },
    )
    .toBe(true);

  fs.mkdirSync(path.dirname(screenshotPath), { recursive: true });
  await page.screenshot({ path: screenshotPath });
  const dim = pngDimensions(screenshotPath);
  expect(dim.width).toBe(1280);
  expect(dim.height).toBe(720);

  await page.getByRole('button', { name: 'E-STOP' }).click();
  await expect(page).toHaveTitle(/latched/i, { timeout: 15_000 });
  await expect(page.getByText(/Speed \(m\/s\): 0\.00/)).toBeVisible({
    timeout: 20_000,
  });

  await page.getByRole('button', { name: 'Reset' }).click();
  await page.getByRole('button', { name: 'Resume' }).click();
  await expect(page).toHaveTitle(/running/i, { timeout: 15_000 });

  const linkLoss = page.getByRole('switch', {
    name: 'Simulate operator link loss',
  });
  await linkLoss.click();
  await expect(page.getByText('Deadman: true')).toBeVisible({
    timeout: 20_000,
  });
  await linkLoss.click();

  await page.getByRole('button', { name: 'Resume' }).click();
  await expect(page).toHaveTitle(/succeeded/i, { timeout: 180_000 });

  expect(requests).toEqual([]);
});
