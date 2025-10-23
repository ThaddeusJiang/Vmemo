import { test, expect } from '@playwright/test';
import { expectPhotoCards, waitForPageLoad, expectFlashMessage } from '../utils/helpers';
import { urls } from '../utils/selectors';

test.describe('照片列表', () => {
  test('应该能够显示照片列表', async ({ page }) => {
    await page.goto(urls.photos);
    await waitForPageLoad(page);

    // 验证页面标题
    await expect(page.locator('h1')).toContainText('Photos');

    // 验证瀑布流组件
    await expect(page.locator('[data-phx-hook="Waterfall"]')).toBeVisible();

    // 验证照片卡片
    await expectPhotoCards(page, 1);
  });

  test('应该能够加载更多照片', async ({ page }) => {
    await page.goto(urls.photos);
    await waitForPageLoad(page);

    // 获取初始照片数量
    const initialCount = await page.locator('.photo-card').count();

    // 滚动到底部触发加载更多
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));

    // 等待加载更多按钮出现
    await page.waitForSelector('button:has-text("Load More")', { timeout: 5000 });

    // 点击加载更多
    await page.click('button:has-text("Load More")');

    // 等待新照片加载
    await page.waitForLoadState('networkidle');

    // 验证新照片加载
    const newCount = await page.locator('.photo-card').count();
    expect(newCount).toBeGreaterThan(initialCount);
  });

  test('应该能够搜索照片', async ({ page }) => {
    await page.goto(urls.photos);
    await waitForPageLoad(page);

    // 在搜索框中输入关键词
    await page.fill('input[name="q"]', '测试');

    // 等待搜索结果
    await page.waitForLoadState('networkidle');

    // 验证搜索结果
    await expectPhotoCards(page, 1);
  });

  test('应该能够清空搜索', async ({ page }) => {
    await page.goto(urls.photos);
    await waitForPageLoad(page);

    // 先进行搜索
    await page.fill('input[name="q"]', '测试');
    await page.waitForLoadState('networkidle');

    // 清空搜索
    await page.fill('input[name="q"]', '');
    await page.waitForLoadState('networkidle');

    // 验证所有照片显示
    await expectPhotoCards(page, 1);
  });

  test('应该能够点击照片进入详情页', async ({ page }) => {
    await page.goto(urls.photos);
    await waitForPageLoad(page);

    // 点击第一张照片
    await page.click('.photo-card:first-child');

    // 验证跳转到详情页
    await expect(page).toHaveURL(/\/photos\/\d+/);

    // 验证详情页内容
    await expect(page.locator('img')).toBeVisible();
  });

  test('应该能够响应式显示', async ({ page }) => {
    // 测试桌面端
    await page.setViewportSize({ width: 1200, height: 800 });
    await page.goto(urls.photos);
    await waitForPageLoad(page);

    // 验证桌面端布局
    await expect(page.locator('[data-phx-hook="Waterfall"]')).toBeVisible();

    // 测试移动端
    await page.setViewportSize({ width: 375, height: 667 });
    await page.reload();
    await waitForPageLoad(page);

    // 验证移动端布局
    await expect(page.locator('[data-phx-hook="Waterfall"]')).toBeVisible();
  });

  test('应该能够处理空状态', async ({ page }) => {
    // 这里需要先清空所有照片，或者使用一个没有照片的测试用户
    await page.goto(urls.photos);
    await waitForPageLoad(page);

    // 如果没有任何照片，应该显示空状态
    const photoCount = await page.locator('.photo-card').count();

    if (photoCount === 0) {
      await expect(page.locator('text=No photos yet')).toBeVisible();
    } else {
      await expectPhotoCards(page, 1);
    }
  });

  test('应该能够显示照片缩略图', async ({ page }) => {
    await page.goto(urls.photos);
    await waitForPageLoad(page);

    // 验证照片缩略图存在
    const firstPhoto = page.locator('.photo-card:first-child img');
    await expect(firstPhoto).toBeVisible();

    // 验证图片加载
    await expect(firstPhoto).toHaveAttribute('src');
  });

  test('应该能够处理网络错误', async ({ page }) => {
    // 模拟网络错误
    await page.route('**/photos**', route => route.abort());

    await page.goto(urls.photos);

    // 验证错误处理
    await expect(page.locator('.flash')).toContainText('Error');
  });
});
