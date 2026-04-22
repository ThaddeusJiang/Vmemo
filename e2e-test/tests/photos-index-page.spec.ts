import { test } from "@playwright/test";
import { expectVisual, gotoAndAssertAttached } from "./visual-helpers.js";

test("photos index page visual snapshot", async ({ page }) => {
  await gotoAndAssertAttached(page, "/images", page.locator("#infinite-scroll"));
  await expectVisual(page, "photos-index-page", [page.locator("#waterfall-images")]);
});
