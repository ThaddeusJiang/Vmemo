import { test } from "@playwright/test";
import { expectVisual, gotoAndAssert } from "./visual-helpers.js";

test("home page visual snapshot", async ({ page }) => {
  await gotoAndAssert(page, "/home", page.getByRole("heading", { name: "Search" }));
  await expectVisual(page, "home-page", [page.getByText(/Total .* photos/)]);
});
