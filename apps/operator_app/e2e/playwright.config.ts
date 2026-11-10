// SPDX-License-Identifier: Apache-2.0

import { defineConfig } from '@playwright/test';
import path from 'node:path';

const serveRoot = path.resolve(__dirname, '../build/serve');
const stagedApp = path.join(serveRoot, 'flutter-robot-operator');
const webBuild = path.resolve(__dirname, '../build/web');

export default defineConfig({
  testDir: '.',
  timeout: 300_000,
  retries: 0,
  use: {
    baseURL: 'http://127.0.0.1:4173/flutter-robot-operator/',
    viewport: { width: 1280, height: 720 },
    headless: true,
  },
  webServer: {
    command: `sh -c 'mkdir -p "${stagedApp}" && cp -r "${webBuild}/"* "${stagedApp}/" && npx http-server "${serveRoot}" -p 4173 -c-1'`,
    url: 'http://127.0.0.1:4173/flutter-robot-operator/',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
