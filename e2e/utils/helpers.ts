import { Page, expect } from '@playwright/test';
import { selectors, testData, urls } from './selectors';

// 认证辅助函数
export async function login(page: Page, email?: string, password?: string) {
  await page.goto(urls.login);
  await page.fill(selectors.login.emailInput, email || 'test@example.com');
  await page.fill(selectors.login.passwordInput, password || 'password123456');
  await page.click(selectors.login.submitButton);
  await page.waitForURL(urls.home);
}

// 照片上传辅助函数
export async function uploadPhoto(page: Page, imagePath: string, note?: string) {
  await page.goto(urls.upload);

  // 等待上传区域可见
  await page.waitForSelector(selectors.upload.form);

  // 触发文件选择器
  const fileChooserPromise = page.waitForEvent('filechooser');
  await page.click(selectors.upload.fileLabel);
  const fileChooser = await fileChooserPromise;

  // 选择测试图片
  await fileChooser.setFiles(imagePath);

  // 等待上传进度
  await page.waitForSelector(selectors.upload.progressBar, { timeout: 30000 });

  // 填写备注（如果提供）
  if (note) {
    await page.fill(selectors.upload.noteTextarea, note);
  }

  // 提交表单
  await page.click(selectors.upload.submitButton);

  // 等待上传完成
  await page.waitForLoadState('networkidle');
}

// 等待并验证 Flash 消息
export async function expectFlashMessage(page: Page, message: string) {
  await expect(page.locator(selectors.common.flashMessage)).toContainText(message);
}

// 等待页面加载完成
export async function waitForPageLoad(page: Page) {
  await page.waitForLoadState('networkidle');
  await page.waitForLoadState('domcontentloaded');
}

// 截图辅助函数
export async function takeScreenshot(page: Page, name: string) {
  await page.screenshot({ path: `test-results/${name}.png`, fullPage: true });
}

// 验证照片卡片存在
export async function expectPhotoCards(page: Page, minCount: number = 1) {
  await expect(page.locator(selectors.photoList.photoCard)).toHaveCount.greaterThanOrEqual(minCount);
}

// 验证照片详情页面
export async function expectPhotoDetail(page: Page) {
  await expect(page.locator(selectors.photoDetail.image)).toBeVisible();
  await expect(page.locator('text=Similar photos')).toBeVisible();
}

// 验证编辑表单
export async function expectEditForm(page: Page) {
  await expect(page.locator(selectors.photoDetail.editForm)).toBeVisible();
  await expect(page.locator(selectors.photoDetail.noteTextarea)).toBeVisible();
  await expect(page.locator(selectors.photoDetail.saveButton)).toBeVisible();
}
