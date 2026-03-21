import path from "node:path";
import { expect, test, type Page } from "@playwright/test";

const email = "test@example.com";
const password = "password123456";
const uploadFile = path.resolve(
  "/Users/amami/git/my2026personal/Vmemo/test/testdata_files/test-red-image.png",
);

async function login(page: Page) {
  await page.goto("/login", { waitUntil: "domcontentloaded" });
  const loginButton = page.getByRole("button", { name: /Login/i });
  const canLogin = await loginButton.isVisible().catch(() => false);
  if (!canLogin) {
    const alreadyLoggedIn = page.getByText("You are currently logged in as");
    return alreadyLoggedIn.isVisible().catch(() => false);
  }

  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(password);
  await loginButton.click();
  await page.waitForURL(/\/home/, { timeout: 20_000 });
  return true;
}

test("login and upload file", async ({ page }) => {
  let loggedIn = await login(page);

  if (!loggedIn) {
    await page.goto("/register", { waitUntil: "domcontentloaded" });
    await expect(page.getByRole("button", { name: /Register/i })).toBeVisible();
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Password").fill(password);
    await page.getByRole("button", { name: /Register/i }).click();
    await page.waitForTimeout(1000);
    loggedIn = await login(page);
  }

  expect(loggedIn).toBeTruthy();
  await page.screenshot({
    path: "/tmp/vmemo-e2e-login-success.png",
    fullPage: true,
  });

  await page.goto("/photos/upload", { waitUntil: "domcontentloaded" });
  await expect(
    page.getByText("Drag and drop images here or click to upload"),
  ).toBeVisible();

  const uploadForm = page.locator("form#upload-form");
  await uploadForm.locator('input[type="file"]').setInputFiles(uploadFile);
  await page.waitForTimeout(1500);

  const note = page.locator('textarea[name="note"]');
  if (await note.isVisible().catch(() => false)) {
    await note.fill("Bun + Playwright TypeScript e2e upload");
  }

  const submitUpload = uploadForm.getByRole("button", { name: /Upload/i });
  await expect(submitUpload).toBeVisible({ timeout: 20_000 });
  await submitUpload.click();

  await page.goto("/photos", { waitUntil: "domcontentloaded" });
  await expect
    .poll(async () => page.locator('a[href^="/photos/"]').count(), {
      timeout: 20_000,
    })
    .toBeGreaterThan(0);

  await page.screenshot({
    path: "/tmp/vmemo-e2e-upload-success.png",
    fullPage: true,
  });
});
