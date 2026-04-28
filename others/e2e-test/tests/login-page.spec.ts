import { test } from "@playwright/test";
import { emptyStorageState, expectVisual, gotoAndAssert } from "./visual-helpers.js";

test.use({ storageState: emptyStorageState });

test("login page visual snapshot", async ({ page }) => {
  await gotoAndAssert(page, "/login", page.getByRole("heading", { name: "Login" }));
  await expectVisual(page, "login-page");
});
