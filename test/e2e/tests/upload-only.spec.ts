import path from "node:path";
import { expect, test } from "@playwright/test";

const uploadFile = path.resolve(
  "/Users/amami/git/my2026personal/Vmemo/test/testdata_files/test-red-image.png",
);

test("upload file with authenticated session", async ({ page }) => {
  await page.goto("/photos/upload", { waitUntil: "domcontentloaded" });
  await expect(
    page.getByText("Drag and drop images here or click to upload"),
  ).toBeVisible();

  const uploadForm = page.locator("form#upload-form");
  await uploadForm.locator('input[type="file"]').setInputFiles(uploadFile);
  await page.waitForTimeout(1500);

  const note = page.locator('textarea[name="note"]');
  if (await note.isVisible().catch(() => false)) {
    await note.fill("Playwright authenticated upload smoke test");
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
