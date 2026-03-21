import { expect, test } from "@playwright/test";

const email = "test@example.com";
const password = "password123456";

test("register and login", async ({ page, context }) => {
  await page.goto("/register", { waitUntil: "domcontentloaded" });

  const registerButton = page.getByRole("button", { name: "Register" });
  if (await registerButton.isVisible().catch(() => false)) {
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Password").fill(password);
    await registerButton.click();
    await page.waitForTimeout(1000);
  } else {
    const alreadyLoggedIn = page.getByText("You are currently logged in as");
    await expect(alreadyLoggedIn).toBeVisible();
  }

  await page.goto("/login", { waitUntil: "domcontentloaded" });

  const loginButton = page.getByRole("button", { name: /Login/i });
  if (!(await loginButton.isVisible().catch(() => false))) {
    const alreadyLoggedIn = page.getByText("You are currently logged in as");
    await expect(alreadyLoggedIn).toBeVisible();
  } else {
    await page.getByLabel("Email").fill(email);
    await page.getByLabel("Password").fill(password);
    await loginButton.click();
    await page.waitForURL(/\/home/, { timeout: 20_000 });
  }

  await page.goto("/home", { waitUntil: "domcontentloaded" });
  await expect(page).toHaveURL(/\/home/);

  await page.screenshot({
    path: "/tmp/vmemo-e2e-home-after-login.png",
    fullPage: true,
  });
  await context.storageState({ path: "/tmp/vmemo-e2e-storage.json" });
});
