import { test } from "@playwright/test";
import { expectVisual, gotoAndAssert } from "./visual-helpers.js";

test("chat list page visual snapshot", async ({ page }) => {
  await gotoAndAssert(page, "/chat", page.getByPlaceholder("Type your message..."));
  await expectVisual(page, "chat-list-page", [page.locator("#conversations-list")]);
});
