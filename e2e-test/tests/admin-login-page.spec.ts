import { test } from "@playwright/test";
import { emptyStorageState, expectVisual, gotoAndAssert } from "./visual-helpers.js";

test.use({ storageState: emptyStorageState });

test("admin login page visual snapshot", async ({ page }) => {
  await gotoAndAssert(page, "/admin/login", page.getByRole("heading", { name: "Admin Login" }));
  await expectVisual(page, "admin-login-page");
});
