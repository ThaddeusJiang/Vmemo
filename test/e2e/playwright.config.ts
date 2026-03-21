import { defineConfig } from "@playwright/test";

const forcedHeadless = process.env.E2E_HEADLESS;
const headless =
  forcedHeadless === undefined
    ? process.env.CI === "true"
    : forcedHeadless === "true";

export default defineConfig({
  testDir: "./tests",
  timeout: 120_000,
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:4000",
    headless,
  },
  workers: 1,
});
