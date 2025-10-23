import { test as setup } from '@playwright/test';

const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  // 导航到登录页面
  await page.goto('/users/log_in');

  // 等待页面加载
  await page.waitForLoadState('networkidle');

  // 填写登录表单
  await page.fill('input[name="user[email]"]', 'test@mail.com');
  await page.fill('input[name="user[password]"]', 'password123456');

  // 提交登录表单
  await page.click('button:has-text("Sign in")');

  // 等待登录成功，重定向到首页
  await page.waitForURL('/home');

  // 保存认证状态
  await page.context().storageState({ path: authFile });

  console.log('Authentication completed and saved to:', authFile);
});
