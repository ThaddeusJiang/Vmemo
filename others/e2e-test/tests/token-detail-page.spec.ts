import { test } from "@playwright/test";
import { createTokenAndOpenDetail, expectVisual } from "./visual-helpers.js";

test("token detail page visual snapshot", async ({ page }) => {
  await createTokenAndOpenDetail(page);
  await expectVisual(page, "token-detail-page", [
    page.locator(".stat-value"),
    page.locator("code"),
    page.locator("text=/\\d{4}-\\d{2}-\\d{2}/"),
  ]);
});
