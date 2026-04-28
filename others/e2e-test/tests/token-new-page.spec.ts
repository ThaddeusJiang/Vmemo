import { test } from "@playwright/test";
import { expectVisual, gotoAndAssert } from "./visual-helpers.js";

test("token new page visual snapshot", async ({ page }) => {
  await gotoAndAssert(
    page,
    "/tokens/new",
    page.getByRole("heading", { name: "Create API Token" }),
  );
  await expectVisual(page, "token-new-page");
});
