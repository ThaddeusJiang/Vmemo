import { test } from "@playwright/test";
import {
  expectVisual,
  gotoAndAssert,
  uploadPhotoAndAssertSuccess,
} from "./visual-helpers.js";

test("photo upload page visual snapshot", async ({ page }) => {
  await gotoAndAssert(
    page,
    "/images/upload",
    page.locator("form#upload-form"),
  );
  await expectVisual(page, "photo-upload-page");
});

test("photo upload page uploads file successfully", async ({ page }) => {
  await uploadPhotoAndAssertSuccess(page);
});
