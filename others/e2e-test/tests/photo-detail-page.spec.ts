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

test("photo detail dialog visual snapshot", async ({ page }, testInfo) => {
  test.skip(
    testInfo.project.name === "iphone-se",
    "Mobile viewport does not expose an expand trigger for the dialog.",
  );

  const noteText = "Playwright visual photo detail dialog";
  await createUploadedPhoto(page, noteText);
  await openUploadedPhotoDetail(page, noteText);

  const photoFigure = page.locator("figure.group").first();
  await photoFigure.hover();
  await page.getByRole("button", { name: "expand" }).first().click();

  await expectVisual(page, "photo-detail-dialog", [
    page.locator("#expanded_photo-bg"),
  ]);
});
