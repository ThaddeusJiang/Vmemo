import { test } from "@playwright/test";
import { emptyStorageState, expectVisual, gotoAndAssert } from "./visual-helpers.js";

test.use({ storageState: emptyStorageState });

test("register page visual snapshot", async ({ page }) => {
  await gotoAndAssert(page, "/register", page.getByRole("heading", { name: "Register" }));
  await expectVisual(page, "register-page");
});
