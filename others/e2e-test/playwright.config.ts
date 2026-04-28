import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  globalSetup: "./global-setup.ts",
  reporter: process.env.CI
    ? [
        ["github"],
        ["html", { open: "never", outputFolder: "playwright-report" }],
      ]
    : [["list"], ["html", { open: "never", outputFolder: "playwright-report" }]],
  timeout: 120_000,
  expect: {
    toHaveScreenshot: {
      animations: "disabled",
      caret: "hide",
      scale: "css",
      maxDiffPixelRatio: 0.02,
    },
  },
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:4000",
    headless: true,
    storageState: "/tmp/vmemo-e2e-storage.json",
  },
  projects: [
    {
      name: "iphone-se",
      use: {
        ...devices["iPhone SE"],
      },
    },
    {
      name: "macbook-13",
      use: {
        ...devices["Desktop Chrome"],
        viewport: {
          width: 1280,
          height: 800,
        },
      },
    },
  ],
  workers: 1,
});
