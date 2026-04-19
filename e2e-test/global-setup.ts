import { chromium, expect, type FullConfig } from "@playwright/test";

const email = "test@example.com";
const password = "pass123456";
const storageStatePath = "/tmp/vmemo-e2e-storage.json";

export default async function globalSetup(config: FullConfig) {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({
    baseURL: config.projects[0]?.use.baseURL,
  });

  try {
    await page.goto("/login", { waitUntil: "domcontentloaded" });

    const loginButton = page.getByRole("button", { name: /Login/i });
    await expect(loginButton).toBeVisible();
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Password").fill(password);
    await loginButton.click();
    await page.waitForURL(/\/home/, { timeout: 20_000 });

    await expect(page).toHaveURL(/\/home/);
    await page.screenshot({
      path: "/tmp/vmemo-e2e-home-after-login.png",
      fullPage: true,
    });
    await page.context().storageState({ path: storageStatePath });
  } finally {
    await browser.close();
  }
}
