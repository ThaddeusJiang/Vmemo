import path from "node:path";
import { expect, type Locator, type Page } from "@playwright/test";

export const emptyStorageState = { cookies: [], origins: [] };
export const seededNoteId = "22222222-2222-4222-8222-222222222222";

const uploadFile = path.resolve(
  import.meta.dirname,
  "../fixtures/upload-files/test-red-image.png",
);

const visualNote = "Playwright visual upload fixture";
const uploadSmokeNote = "Playwright authenticated upload smoke test";
const visualChatMessage = "Playwright visual chat fixture";
const visualTokenName = "Playwright Visual Token";

export async function gotoAndAssert(
  page: Page,
  path: string,
  ready: Locator,
) {
  await page.goto(path, { waitUntil: "domcontentloaded" });
  await expect(ready).toBeVisible({ timeout: 20_000 });
  await settlePage(page);
}

export async function gotoAndAssertAttached(
  page: Page,
  path: string,
  ready: Locator,
) {
  await page.goto(path, { waitUntil: "domcontentloaded" });
  await expect(ready).toHaveCount(1, { timeout: 20_000 });
  await settlePage(page);
}

export async function expectVisual(
  page: Page,
  name: string,
  mask: Locator[] = [],
) {
  await settlePage(page);
  await page.screenshot({
    path: `/tmp/${name}.png`,
    fullPage: true,
  });
  await expect(page).toHaveScreenshot(`${name}.png`, {
    fullPage: true,
    mask,
  });
}

export async function createUploadedPhoto(page: Page, noteText = visualNote) {
  const uploadForm = await prepareUploadForm(page, noteText);
  const submitUpload = uploadForm.getByRole("button", { name: /Upload/i });
  await submitUpload.click();

  await page.goto("/photos", { waitUntil: "domcontentloaded" });
  await expect
    .poll(async () => page.locator('a[href^="/photos/"]', { has: page.locator(`img[alt="${noteText}"]`) }).count(), {
      timeout: 20_000,
    })
    .toBeGreaterThan(0);

  return noteText;
}

export async function uploadPhotoAndAssertSuccess(page: Page) {
  const uploadForm = await prepareUploadForm(page, uploadSmokeNote);
  const submitUpload = uploadForm.getByRole("button", { name: /Upload/i });
  await submitUpload.click();

  await page.goto("/photos", { waitUntil: "domcontentloaded" });
  await expect
    .poll(
      async () =>
        page
          .locator('a[href^="/photos/"]', {
            has: page.locator(`img[alt="${uploadSmokeNote}"]`),
          })
          .count(),
      {
      timeout: 20_000,
      },
    )
    .toBeGreaterThan(0);

  await page.screenshot({
    path: "/tmp/vmemo-e2e-upload-success.png",
    fullPage: true,
  });
}

export async function openUploadedPhotoDetail(page: Page, noteText: string) {
  await page.goto("/photos", { waitUntil: "domcontentloaded" });
  const photoLink = page
    .locator('a[href^="/photos/"]', {
      has: page.locator(`img[alt="${noteText}"]`),
    })
    .first();
  await expect(photoLink).toBeVisible({ timeout: 20_000 });
  await photoLink.click();
  await expect(page).toHaveURL(/\/photos\/.+/);
  await expect(page.locator('textarea[name="note"]')).toBeVisible({ timeout: 20_000 });
}

export async function createConversation(page: Page) {
  await page.goto("/chat", { waitUntil: "domcontentloaded" });
  await expect(page.getByPlaceholder("Type your message...")).toBeVisible();
  await page.getByPlaceholder("Type your message...").fill(visualChatMessage);
  await page.getByRole("button", { name: "Send" }).click();
  await expect(page).toHaveURL(/\/chat\/.+/, { timeout: 20_000 });
  await expect(page.locator("#message-container .chat-bubble").first()).toBeVisible({
    timeout: 20_000,
  });
}

export async function createTokenAndOpenDetail(page: Page) {
  await page.goto("/tokens/new", { waitUntil: "domcontentloaded" });
  await expect(page.getByRole("heading", { name: "Create API Token" })).toBeVisible();

  await page.getByLabel("Token Name").fill(visualTokenName);
  await page.getByLabel("Expiration").selectOption("30");
  await page.getByRole("button", { name: "Save" }).click();

  await expect(page.getByText("Token Created Successfully")).toBeVisible({
    timeout: 20_000,
  });

  await page.getByRole("button", { name: "I've Saved It" }).click();
  await page.waitForTimeout(500);

  if (!page.url().endsWith("/tokens")) {
    await page.goto("/tokens", { waitUntil: "domcontentloaded" });
  }

  await expect(page).toHaveURL("/tokens");

  const tokenRow = page.locator("tr", { hasText: visualTokenName }).first();
  await expect(tokenRow).toBeVisible({ timeout: 20_000 });

  const tokenId = await tokenRow
    .locator("button[phx-value-id]")
    .first()
    .getAttribute("phx-value-id");

  if (!tokenId) {
    throw new Error("Failed to resolve token id from tokens table");
  }

  await page.goto(`/tokens/${tokenId}`, { waitUntil: "domcontentloaded" });
  await expect(page.getByRole("heading", { name: "API Token Details" })).toBeVisible();
}

async function settlePage(page: Page) {
  await page.waitForLoadState("networkidle").catch(() => undefined);
  await page.waitForTimeout(300);
}

async function prepareUploadForm(page: Page, noteText: string) {
  let lastError: unknown;

  for (const _attempt of [1, 2]) {
    try {
      await page.goto("/photos/upload", { waitUntil: "domcontentloaded" });
      await expect(page.getByText("Drag and drop images here or click to upload")).toBeVisible();

      const uploadForm = page.locator("form#upload-form");
      await uploadForm.locator('input[type="file"]').setInputFiles(uploadFile);

      const note = page.locator('textarea[name="note"]');
      await expect(note).toBeVisible({ timeout: 20_000 });
      await note.fill(noteText);
      await page.getByLabel("Is whole").setChecked(true);

      const submitUpload = uploadForm.getByRole("button", { name: /Upload/i });
      await expect(submitUpload).toBeVisible({ timeout: 20_000 });

      return uploadForm;
    } catch (error) {
      lastError = error;
    }
  }

  throw lastError;
}
