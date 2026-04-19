import { test } from "@playwright/test";
import { emptyStorageState, expectVisual, gotoAndAssert } from "./visual-helpers.js";

test.use({ storageState: emptyStorageState });

test("forgot password page visual snapshot", async ({ page }) => {
  await gotoAndAssert(
    page,
    "/reset-password",
    page.getByRole("heading", { name: "Forgot your password?" }),
  );
  await expectVisual(page, "forgot-password-page");
});
