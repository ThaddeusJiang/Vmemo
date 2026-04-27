import { chromium, expect, type FullConfig } from "@playwright/test";

const email = "test@example.com";
const password = "pass123456";
const storageStatePath = "/tmp/vmemo-e2e-storage.json";
const loginRetryTimeoutMs = 60_000;
const loginRetryIntervalMs = 2_000;

export default async function globalSetup(config: FullConfig) {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({
    baseURL: config.projects[0]?.use.baseURL,
  });

  try {
    const deadline = Date.now() + loginRetryTimeoutMs;
    let lastError: unknown;

    while (Date.now() < deadline) {
      try {
        await page.goto("/login", { waitUntil: "domcontentloaded" });

        const loginButton = page.getByRole("button", { name: /Login/i });
        await expect(loginButton).toBeVisible({ timeout: 10_000 });
        await page.getByLabel("Email").fill(email);
        await page.getByLabel("Password").fill(password);
        await loginButton.click();
        await expect(page).toHaveURL(/\/home/, { timeout: 10_000 });
        lastError = undefined;
        break;
      } catch (error) {
        lastError = error;
        await page.waitForTimeout(loginRetryIntervalMs);
      }
    }

    if (lastError) {
      throw lastError;
    }

    await page.screenshot({
      path: "/tmp/vmemo-e2e-home-after-login.png",
      fullPage: true,
    });
    await page.context().storageState({ path: storageStatePath });
  } finally {
    await browser.close();
  }
}
