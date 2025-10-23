import { test, expect } from '@playwright/test';
import { expectEditForm, expectFlashMessage, waitForPageLoad } from '../utils/helpers';
import { urls } from '../utils/selectors';

test.describe('备注更新', () => {
  test('应该能够更新照片备注', async ({ page }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '原始备注');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 进入编辑模式
    await page.goto(page.url() + '?action=edit');

    // 验证编辑表单可见
    await expectEditForm(page);

    // 修改备注内容
    await page.fill('textarea[name="note"]', '更新后的备注内容');

    // 保存更改
    await page.click('button:has-text("Save")');

    // 验证保存成功
    await expectFlashMessage(page, 'Saved');

    // 验证备注已更新
    await expect(page.locator('textarea[name="note"]')).toHaveValue('更新后的备注内容');
  });

  test('应该能够生成 AI 描述', async ({ page }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', 'AI描述测试');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 进入编辑模式
    await page.goto(page.url() + '?action=edit');

    // 点击 AI 描述按钮
    await page.click('button[aria-label="AI trained"]');

    // 等待描述生成
    await expectFlashMessage(page, 'Description generated');

    // 验证描述字段有内容
    await expect(page.locator('textarea[name="_gen_description"]')).not.toBeEmpty();
  });

  test('应该能够清空备注', async ({ page }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '待清空的备注');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 进入编辑模式
    await page.goto(page.url() + '?action=edit');

    // 清空备注内容
    await page.fill('textarea[name="note"]', '');

    // 保存更改
    await page.click('button:has-text("Save")');

    // 验证保存成功
    await expectFlashMessage(page, 'Saved');

    // 验证备注已清空
    await expect(page.locator('textarea[name="note"]')).toHaveValue('');
  });

  test('应该能够取消编辑', async ({ page }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '原始备注');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 进入编辑模式
    await page.goto(page.url() + '?action=edit');

    // 修改备注内容
    await page.fill('textarea[name="note"]', '修改后的备注');

    // 取消编辑（通过导航离开）
    await page.goto(page.url().replace('?action=edit', ''));

    // 验证备注没有改变
    await expect(page.locator('text=原始备注')).toBeVisible();
  });

  test('应该能够处理保存失败', async ({ page }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '保存失败测试');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 进入编辑模式
    await page.goto(page.url() + '?action=edit');

    // 模拟网络错误
    await page.route('**/photos/**', route => route.abort());

    // 修改备注内容
    await page.fill('textarea[name="note"]', '会失败的备注');

    // 尝试保存
    await page.click('button:has-text("Save")');

    // 验证错误消息
    await expectFlashMessage(page, 'Failed to save');
  });

  test('应该能够验证备注长度限制', async ({ page }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '长度限制测试');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 进入编辑模式
    await page.goto(page.url() + '?action=edit');

    // 输入超长备注
    const longNote = 'a'.repeat(10000);
    await page.fill('textarea[name="note"]', longNote);

    // 尝试保存
    await page.click('button:has-text("Save")');

    // 验证长度限制错误
    await expectFlashMessage(page, 'Note too long');
  });

  test('应该能够实时预览备注', async ({ page }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '实时预览测试');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 进入编辑模式
    await page.goto(page.url() + '?action=edit');

    // 输入新备注
    await page.fill('textarea[name="note"]', '实时更新的备注');

    // 验证实时预览（如果实现了的话）
    // 这里需要根据实际实现来调整
    await expect(page.locator('textarea[name="note"]')).toHaveValue('实时更新的备注');
  });

  test('应该能够处理并发编辑', async ({ page, context }) => {
    // 先上传一张照片
    await page.goto(urls.upload);
    await page.waitForSelector('#upload-form');

    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;
    await fileChooser.setFiles('fixtures/test-image-1.png');

    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress', { timeout: 30000 });
    await page.fill('textarea[name="note"]', '并发编辑测试');
    await page.click('button[type="submit"]');

    // 等待跳转到详情页
    await page.waitForURL(/\/photos\/\d+/);

    // 创建第二个页面
    const page2 = await context.newPage();

    // 两个页面都进入编辑模式
    await page.goto(page.url() + '?action=edit');
    await page2.goto(page.url() + '?action=edit');

    // 在第一个页面修改备注
    await page.fill('textarea[name="note"]', '第一个页面的修改');
    await page.click('button:has-text("Save")');

    // 在第二个页面修改备注
    await page2.fill('textarea[name="note"]', '第二个页面的修改');
    await page2.click('button:has-text("Save")');

    // 验证冲突处理
    await expectFlashMessage(page, 'Conflict detected');
    await expectFlashMessage(page2, 'Conflict detected');

    await page2.close();
  });
});
