import { test } from "@playwright/test";
import {
  expectVisual,
  gotoAndAssert,
  uploadPhotoAndAssertSuccess,
} from "./visual-helpers.js";

test("photo upload page visual snapshot", async ({ page }) => {
  await gotoAndAssert(
    page,
    "/photos/upload",
    page.getByText("Drag and drop images here or click to upload"),
  );
  await expectVisual(page, "photo-upload-page");
});

test("photo upload page uploads file successfully", async ({ page }) => {
  await uploadPhotoAndAssertSuccess(page);
});
