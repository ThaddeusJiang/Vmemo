import { test, expect } from '@playwright/test';
import { expectPhotoDetail, expectFlashMessage, waitForPageLoad } from '../utils/helpers';
import { urls } from '../utils/selectors';

test.describe('照片详情', () => {
  test('应该能够查看照片详情', async ({ page }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '测试照片详情');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 验证详情页面内容
    await expectPhotoDetail(page);

    // 验证照片显示
    await expect(page.locator('img')).toBeVisible();

    // 验证相似照片区域
    await expect(page.locator('text=Similar photos')).toBeVisible();

    // 验证备注区域
    await expect(page.locator('text=References')).toBeVisible();
  });

  test('应该能够删除照片', async ({ page }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '待删除的照片');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 悬停显示删除按钮
    await page.hover('figure.group');

    // 点击删除按钮
    await page.click('button[aria-label="delete"]');

    // 确认删除
    await page.click('button:has-text("Yes")');

    // 验证跳转到照片列表
    await expect(page).toHaveURL('/photos');
    await expectFlashMessage(page, 'Deleted');
  });

  test('应该能够展开照片查看', async ({ page }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '可展开的照片');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 点击展开按钮
    await page.click('button[aria-label="expand"]');

    // 验证模态框显示
    await expect(page.locator('.modal')).toBeVisible();

    // 验证模态框中的图片
    await expect(page.locator('.modal img')).toBeVisible();

    // 关闭模态框
    await page.click('.modal .btn-close');

    // 验证模态框关闭
    await expect(page.locator('.modal')).not.toBeVisible();
  });

  test('应该能够查看相似照片', async ({ page }) => {
    // 先上传多张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles(['fixtures/test-image-1.png', 'fixtures/test-image-2.png']);

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '相似照片测试');
    await page.click('button[type="submit"]');

    // 等待跳转到照片列表
    await page.waitForURL('/photos');

    // 点击第一张照片进入详情
    await page.click('.photo-card:first-child');

    // 验证相似照片区域
    await expect(page.locator('text=Similar photos')).toBeVisible();

    // 验证相似照片存在
    const similarPhotos = page.locator('.similar-photos .photo-card');
    await expect(similarPhotos).toHaveCount.greaterThan(0);
  });

  test('应该能够点击相似照片跳转', async ({ page }) => {
    // 先上传多张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles(['fixtures/test-image-1.png', 'fixtures/test-image-2.png']);

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '相似照片跳转测试');
    await page.click('button[type="submit"]');

    // 等待跳转到照片列表
    await page.waitForURL('/photos');

    // 点击第一张照片进入详情
    await page.click('.photo-card:first-child');

    // 点击相似照片
    await page.click('.similar-photos .photo-card:first-child');

    // 验证跳转到新的详情页
    await expect(page).toHaveURL(/\/photos\/\d+/);
  });

  test('应该能够处理不存在的照片', async ({ page }) => {
    // 访问不存在的照片ID
    await page.goto('/photos/999999');

    // 验证404页面
    await expect(page.locator('text=Not Found')).toBeVisible();
  });

  test('应该能够响应式显示详情页', async ({ page }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '响应式测试');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 测试桌面端
    await page.setViewportSize({ width: 1200, height: 800 });
    await page.reload();
    await waitForPageLoad(page);

    // 验证桌面端布局
    await expect(page.locator('img')).toBeVisible();

    // 测试移动端
    await page.setViewportSize({ width: 375, height: 667 });
    await page.reload();
    await waitForPageLoad(page);

    // 验证移动端布局
    await expect(page.locator('img')).toBeVisible();
  });

  test('应该能够显示照片元数据', async ({ page }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '元数据测试');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 验证照片信息显示
    await expect(page.locator('text=元数据测试')).toBeVisible();
  });
});
