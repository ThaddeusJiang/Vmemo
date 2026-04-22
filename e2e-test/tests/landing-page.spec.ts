import { test } from "@playwright/test";
import { emptyStorageState, expectVisual, gotoAndAssert } from "./visual-helpers.js";

test.use({ storageState: emptyStorageState });

test("landing page visual snapshot", async ({ page }) => {
  await gotoAndAssert(
    page,
    "/",
    page.getByRole("heading", { name: /See less text\./i }),
  );
  await expectVisual(page, "landing-page", [page.getByAltText("Deployed on Zeabur")]);
});
