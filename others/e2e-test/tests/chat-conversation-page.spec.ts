import { test } from "@playwright/test";
import { createConversation, expectVisual } from "./visual-helpers.js";

test("chat conversation page visual snapshot", async ({ page }) => {
  await createConversation(page);
  await expectVisual(page, "chat-conversation-page", [
    page.locator("#message-container"),
    page.locator("#conversations-list"),
    page.locator("#conversation-title-editor"),
  ]);
});
