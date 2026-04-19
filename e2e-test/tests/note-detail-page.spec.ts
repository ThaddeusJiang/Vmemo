import { test } from "@playwright/test";
import { expectVisual, gotoAndAssert, seededNoteId } from "./visual-helpers.js";

test("note detail page visual snapshot", async ({ page }) => {
  await gotoAndAssert(page, `/notes/${seededNoteId}`, page.locator('textarea[name="note"]'));
  await expectVisual(page, "note-detail-page");
});
