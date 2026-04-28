import { test } from "@playwright/test";
import {
  createUploadedPhoto,
  expectVisual,
  openUploadedPhotoDetail,
} from "./visual-helpers.js";

test("photo detail page visual snapshot", async ({ page }) => {
  const noteText = "Playwright visual photo detail";
  await createUploadedPhoto(page, noteText);
  await openUploadedPhotoDetail(page, noteText);
  await expectVisual(page, "photo-detail-page", [
    page.locator("text=/Similar photos\\(\\d+\\)/"),
    page.locator("text=/References\\(\\d+\\)/"),
  ]);
});
