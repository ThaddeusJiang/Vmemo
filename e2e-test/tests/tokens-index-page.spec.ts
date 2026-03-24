import { test } from "@playwright/test";
import { expectVisual, gotoAndAssert } from "./visual-helpers.js";

test("tokens index page visual snapshot", async ({ page }) => {
  await gotoAndAssert(page, "/tokens", page.locator("h1", { hasText: "Tokens" }));
  await expectVisual(page, "tokens-index-page", [
    page.locator(".stat-value"),
    page.locator("#api-tokens"),
  ]);
});
