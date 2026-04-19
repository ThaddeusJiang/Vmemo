import { test } from "@playwright/test";
import { expectVisual, gotoAndAssert } from "./visual-helpers.js";

test("settings page visual snapshot", async ({ page }) => {
  await gotoAndAssert(
    page,
    "/settings",
    page.getByRole("heading", { name: "Account Settings" }),
  );
  await expectVisual(page, "settings-page");
});
