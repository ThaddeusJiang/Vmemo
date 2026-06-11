import { expect, test } from "@playwright/test";
import { expectVisual, gotoAndAssertAttached } from "./visual-helpers.js";

test("photos index page visual snapshot", async ({ page }) => {
  await gotoAndAssertAttached(page, "/images", page.locator("#infinite-scroll"));
  const firstImage = page.locator("#waterfall-images img").first();

  await expect(firstImage).toBeVisible({ timeout: 20_000 });
  await expect
    .poll(() =>
      firstImage.evaluate((image) => (image as HTMLImageElement).naturalWidth),
    )
    .toBeGreaterThan(0);

  await expectVisual(page, "photos-index-page", [
    page.locator(".page-shell"),
    page.getByLabel("Notifications"),
  ]);
});
