import { test } from "@playwright/test";
import { emptyStorageState, expectVisual, gotoAndAssert } from "./visual-helpers.js";

test.use({ storageState: emptyStorageState });

test("confirmation instructions page visual snapshot", async ({ page }) => {
  await gotoAndAssert(
    page,
    "/users/confirm",
    page.getByRole("heading", { name: "No confirmation instructions received?" }),
  );
  await expectVisual(page, "confirmation-instructions-page");
});
