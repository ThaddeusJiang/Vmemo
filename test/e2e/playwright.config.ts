import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  globalSetup: "./global-setup.ts",
  timeout: 120_000,
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:4000",
    headless: true,
    storageState: "/tmp/vmemo-e2e-storage.json",
  },
  workers: 1,
});
