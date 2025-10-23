import { test, expect } from '@playwright/test';

test.describe('Vmemo 实际测试用例', () => {
  test('基于实际测试的完整工作流程', async ({ page }) => {
    // 1. 访问首页并验证登录状态
    await page.goto('http://localhost:4000');
    await page.waitForLoadState('networkidle');

    // 验证首页加载成功
    await expect(page.locator('text=See, Capture, Remember')).toBeVisible();

    // 点击Get started进入应用
    await page.click('text=Get started');
    await page.waitForLoadState('networkidle');

    // 验证已登录状态（用户头像按钮可见）
    await expect(page.locator('button:has-text("t")')).toBeVisible();

    // 2. 测试照片上传功能
    await page.click('a[href="/upload"]');
    await page.waitForURL('/upload');

    // 验证上传页面加载
    await expect(page.locator('text=Drag and drop images here or click to upload')).toBeVisible();

    // 点击上传区域
    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('text=Drag and drop images here or click to upload');
    const fileChooser = await fileChooserPromise;

    // 上传测试图片
    await fileChooser.setFiles(['/Users/tj/git/personal/Vmemo/e2e/fixtures/test-image-1.png']);

    // 验证图片预览出现
    await expect(page.locator('article figure img')).toBeVisible();

    // 添加备注
    await page.fill('textarea[name="note"]', '实际测试照片备注');

    // 点击上传按钮
    await page.click('button:has-text("Upload")');

    // 等待上传完成（按钮变为Processing...然后页面重置）
    await page.waitForSelector('button:has-text("Processing...")', { timeout: 10000 });
    await page.waitForSelector('text=Drag and drop images here or click to upload', { timeout: 30000 });

    // 3. 测试照片详情和备注编辑
    await page.goto('/home');
    await page.waitForLoadState('networkidle');

    // 点击第一张照片
    const photoLink = page.locator('main a').first();
    await photoLink.click();

    // 等待详情页加载
    await page.waitForURL(/\/photos\/[a-f0-9-]+/);

    // 验证详情页元素
    await expect(page.locator('figure img')).toBeVisible();
    await expect(page.locator('textbox[name="note"]')).toBeVisible();
    await expect(page.locator('textbox[name="description"]')).toBeVisible();

    // 编辑备注
    await page.fill('textbox[name="note"]', '更新后的实际测试备注');

    // 保存备注
    await page.click('button:has-text("Save")');

    // 验证保存成功
    await expect(page.locator('text=Success!')).toBeVisible();
    await expect(page.locator('text=Saved')).toBeVisible();

    // 验证备注内容已更新
    await expect(page.locator('textbox[name="note"]')).toHaveValue('更新后的实际测试备注');
  });

  test('用户界面元素验证', async ({ page }) => {
    await page.goto('http://localhost:4000');
    await page.waitForLoadState('networkidle');

    // 点击Get started
    await page.click('text=Get started');
    await page.waitForLoadState('networkidle');

    // 验证导航栏元素
    await expect(page.locator('a[href="/home"]')).toBeVisible(); // Logo链接
    await expect(page.locator('input[placeholder="Search"]')).toBeVisible(); // 搜索框
    await expect(page.locator('a[href="/upload"]')).toBeVisible(); // 上传链接
    await expect(page.locator('button:has-text("t")')).toBeVisible(); // 用户菜单

    // 测试用户菜单
    await page.click('button:has-text("t")');
    await expect(page.locator('text=Upload')).toBeVisible();
    await expect(page.locator('text=Settings')).toBeVisible();
    await expect(page.locator('text=Sign out')).toBeVisible();
  });

  test('搜索功能测试', async ({ page }) => {
    await page.goto('http://localhost:4000');
    await page.waitForLoadState('networkidle');

    await page.click('text=Get started');
    await page.waitForLoadState('networkidle');

    // 在搜索框中输入内容
    await page.fill('input[placeholder="Search"]', '测试');
    await page.waitForTimeout(1000); // 等待搜索完成

    // 验证搜索框内容
    await expect(page.locator('input[placeholder="Search"]')).toHaveValue('测试');
  });

  test('响应式布局测试', async ({ page }) => {
    // 测试桌面端
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('http://localhost:4000');
    await page.waitForLoadState('networkidle');

    await page.click('text=Get started');
    await page.waitForLoadState('networkidle');

    // 验证桌面端布局
    await expect(page.locator('banner')).toBeVisible();
    await expect(page.locator('main')).toBeVisible();

    // 测试移动端
    await page.setViewportSize({ width: 375, height: 667 });
    await page.reload();
    await page.waitForLoadState('networkidle');

    // 验证移动端布局
    await expect(page.locator('banner')).toBeVisible();
    await expect(page.locator('main')).toBeVisible();

    // 测试移动端用户菜单
    await page.click('button:has-text("t")');
    await expect(page.locator('text=Sign out')).toBeVisible();
  });
});
