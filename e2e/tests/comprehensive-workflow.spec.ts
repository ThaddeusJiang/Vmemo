import { test, expect } from '@playwright/test';
import { testData, urls, selectors } from '../utils/selectors';

test.describe('Vmemo 完整工作流程测试', () => {
  test('完整的用户工作流程：登录 -> 上传 -> 查看 -> 编辑备注', async ({ page }) => {
    // 1. 验证用户已登录状态
    await page.goto('/home');
    await page.waitForLoadState('networkidle');

    // 验证用户菜单可见（表示已登录）
    await page.click('button:has-text("t")');
    await expect(page.locator('text=Sign out')).toBeVisible();

    // 2. 测试照片上传功能
    await page.click('a[href="/upload"]');
    await page.waitForURL('/upload');

    // 等待上传区域可见
    await page.waitForSelector('text=Drag and drop images here or click to upload');

    // 点击上传区域触发文件选择器
    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('text=Drag and drop images here or click to upload');
    const fileChooser = await fileChooserPromise;

    // 上传测试图片
    await fileChooser.setFiles([testData.testImage1]);

    // 等待图片预览出现
    await expect(page.locator('article figure img')).toBeVisible();

    // 添加备注
    await page.fill('textarea[name="note"]', '综合测试照片备注');

    // 点击上传按钮
    await page.click('button:has-text("Upload")');

    // 等待上传完成（按钮变为Processing...然后页面重置）
    await page.waitForSelector('button:has-text("Processing...")', { timeout: 10000 });
    await page.waitForSelector('text=Drag and drop images here or click to upload', { timeout: 30000 });

    // 3. 测试照片列表功能
    await page.goto('/home');
    await page.waitForLoadState('networkidle');

    // 验证照片列表页面加载
    await expect(page.locator('main')).toBeVisible();

    // 测试搜索功能
    await page.fill('input[placeholder="Search"]', '综合测试');
    await page.waitForTimeout(1000); // 等待搜索完成

    // 4. 测试照片详情和备注编辑
    // 点击第一张照片进入详情页
    const photoLink = page.locator('main a').first();
    await photoLink.click();

    // 等待详情页加载
    await page.waitForURL(/\/photos\/[a-f0-9-]+/);

    // 验证照片详情页元素
    await expect(page.locator('figure img')).toBeVisible();
    await expect(page.locator('textbox[name="note"]')).toBeVisible();
    await expect(page.locator('textbox[name="description"]')).toBeVisible();

    // 编辑备注
    await page.fill('textbox[name="note"]', '更新后的备注内容');

    // 保存备注
    await page.click('button:has-text("Save")');

    // 验证保存成功消息
    await expect(page.locator('text=Success!')).toBeVisible();
    await expect(page.locator('text=Saved')).toBeVisible();

    // 验证备注内容已更新
    await expect(page.locator('textbox[name="note"]')).toHaveValue('更新后的备注内容');
  });

  test('用户界面响应式测试', async ({ page }) => {
    // 测试桌面端视图
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('/home');
    await page.waitForLoadState('networkidle');

    // 验证桌面端布局
    await expect(page.locator('banner')).toBeVisible();
    await expect(page.locator('main')).toBeVisible();

    // 测试移动端视图
    await page.setViewportSize({ width: 375, height: 667 });
    await page.reload();
    await page.waitForLoadState('networkidle');

    // 验证移动端布局
    await expect(page.locator('banner')).toBeVisible();
    await expect(page.locator('main')).toBeVisible();

    // 测试用户菜单在移动端
    await page.click('button:has-text("t")');
    await expect(page.locator('text=Sign out')).toBeVisible();
  });

  test('错误处理和边界情况', async ({ page }) => {
    // 测试不存在的照片页面
    await page.goto('/photos/non-existent-id');
    await page.waitForLoadState('networkidle');

    // 应该显示404或错误页面
    await expect(page.locator('text=404')).toBeVisible();

    // 测试无效的URL
    await page.goto('/invalid-route');
    await page.waitForLoadState('networkidle');

    // 应该重定向到首页或显示错误
    const currentUrl = page.url();
    expect(currentUrl).toMatch(/\/(home|404)/);
  });

  test('用户认证状态管理', async ({ page }) => {
    // 验证登录状态持久化
    await page.goto('/home');
    await page.waitForLoadState('networkidle');

    // 刷新页面验证登录状态保持
    await page.reload();
    await page.waitForLoadState('networkidle');

    // 验证用户菜单仍然可用
    await page.click('button:has-text("t")');
    await expect(page.locator('text=Sign out')).toBeVisible();

    // 测试登出功能
    await page.click('text=Sign out');
    await page.waitForURL('/users/log_in');

    // 验证已登出
    await expect(page.locator('text=Sign in')).toBeVisible();
  });

  test('照片上传的多种方式', async ({ page }) => {
    await page.goto('/upload');
    await page.waitForLoadState('networkidle');

    // 方式1：点击上传区域
    const fileChooserPromise1 = page.waitForEvent('filechooser');
    await page.click('text=Drag and drop images here or click to upload');
    const fileChooser1 = await fileChooserPromise1;
    await fileChooser1.setFiles([testData.testImage1]);

    // 等待预览出现
    await expect(page.locator('article figure img')).toBeVisible();

    // 取消上传
    await page.click('button:has-text("cancel")');

    // 方式2：通过文件输入框（如果存在）
    const fileInput = page.locator('input[type="file"]');
    if (await fileInput.isVisible()) {
      const fileChooserPromise2 = page.waitForEvent('filechooser');
      await fileInput.click();
      const fileChooser2 = await fileChooserPromise2;
      await fileChooser2.setFiles([testData.testImage2]);
      await expect(page.locator('article figure img')).toBeVisible();
    }
  });

  test('备注编辑的实时保存', async ({ page }) => {
    // 先上传一张照片
    await page.goto('/upload');
    await page.waitForLoadState('networkidle');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('text=Drag and drop images here or click to upload');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles([testData.testImage1]);

    await page.fill('textarea[name="note"]', '实时保存测试');
    await page.click('button:has-text("Upload")');

    // 等待上传完成
    await page.waitForSelector('text=Drag and drop images here or click to upload', { timeout: 30000 });

    // 进入详情页测试备注编辑
    await page.goto('/home');
    await page.waitForLoadState('networkidle');

    const photoLink = page.locator('main a').first();
    await photoLink.click();

    await page.waitForURL(/\/photos\/[a-f0-9-]+/);

    // 测试多次编辑和保存
    const testNotes = [
      '第一次编辑',
      '第二次编辑',
      '第三次编辑'
    ];

    for (const note of testNotes) {
      await page.fill('textbox[name="note"]', note);
      await page.click('button:has-text("Save")');

      // 验证保存成功
      await expect(page.locator('text=Success!')).toBeVisible();
      await expect(page.locator('textbox[name="note"]')).toHaveValue(note);

      // 等待成功消息消失
      await page.waitForSelector('text=Success!', { state: 'hidden', timeout: 5000 });
    }
  });
});
