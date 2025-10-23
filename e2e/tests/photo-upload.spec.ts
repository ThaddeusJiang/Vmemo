import { test, expect } from '@playwright/test';
import { uploadPhoto, expectFlashMessage, waitForPageLoad } from '../utils/helpers';
import { testData, urls } from '../utils/selectors';

test.describe('照片上传', () => {
  test('应该能够成功上传单张照片', async ({ page }) => {
    await uploadPhoto(page, testData.testImage1, testData.testNote);

    // 验证上传成功
    await expect(page).toHaveURL(/\/photos\/\d+/);
    await expectFlashMessage(page, 'Photos uploaded successfully');
  });

  test('应该能够上传多张照片', async ({ page }) => {
    await page.goto(urls.upload);

    // 等待上传区域可见
    await page.waitForSelector('#upload-form');

    // 触发文件选择器
    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;

    // 选择多张测试图片
    await fileChooser.setFiles([testData.testImage1, testData.testImage2]);

    // 等待上传进度
    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });

    // 填写备注
    await page.fill('textarea[name="note"]', '批量上传测试');

    // 提交表单
    await page.click('button[type="submit"]');

    // 验证上传成功
    await expect(page).toHaveURL('/photos');
    await expectFlashMessage(page, 'Photos uploaded successfully');
  });

  test('应该能够通过拖拽上传照片', async ({ page }) => {
    await page.goto(urls.upload);

    // 等待上传区域可见
    await page.waitForSelector('#upload-form');

    // 获取拖拽目标
    const dropTarget = page.locator('[phx-drop-target]');

    // 模拟拖拽文件
    await dropTarget.dispatchEvent('dragover');
    await dropTarget.dispatchEvent('drop', {
      dataTransfer: {
        files: [testData.testImage1]
      }
    });

    // 等待上传进度
    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });

    // 填写备注
    await page.fill('textarea[name="note"]', '拖拽上传测试');

    // 提交表单
    await page.click('button[type="submit"]');

    // 验证上传成功
    await expect(page).toHaveURL('/photos');
    await expectFlashMessage(page, 'Photos uploaded successfully');
  });

  test('应该能够处理上传失败的情况', async ({ page }) => {
    await page.goto(urls.upload);

    // 等待上传区域可见
    await page.waitForSelector('#upload-form');

    // 尝试上传不存在的文件
    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;

    // 选择不存在的文件（这会触发错误）
    await fileChooser.setFiles('non-existent-file.jpg');

    // 等待错误消息
    await expect(page.locator('.flash')).toContainText('Failed to upload photo');
  });

  test('应该能够验证文件类型限制', async ({ page }) => {
    await page.goto(urls.upload);

    // 等待上传区域可见
    await page.waitForSelector('#upload-form');

    // 创建一个临时文本文件
    const tempFile = 'fixtures/test.txt';
    await page.evaluate(async (filePath) => {
      const fs = require('fs');
      fs.writeFileSync(filePath, 'This is a test file');
    }, tempFile);

    // 尝试上传文本文件
    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;

    await fileChooser.setFiles(tempFile);

    // 验证文件类型被拒绝
    await expect(page.locator('.flash')).toContainText('Invalid file type');
  });

  test('应该能够显示上传进度', async ({ page }) => {
    await page.goto(urls.upload);

    // 等待上传区域可见
    await page.waitForSelector('#upload-form');

    // 触发文件选择器
    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;

    // 选择测试图片
    await fileChooser.setFiles(testData.testImage1);

    // 验证上传进度条显示
    await expect(page.locator('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress')).toBeVisible();

    // 等待上传完成
    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { state: 'hidden', timeout: 30000 });
  });
});
