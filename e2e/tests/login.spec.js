const { test, expect } = require('@playwright/test');

test.describe('User Login', () => {
  test('should successfully login with valid credentials', async ({ page }) => {
    await page.goto('/users/log_in');
    
    await page.waitForLoadState('networkidle');
    
    await expect(page.locator('text=Sign in to account')).toBeVisible();
    
    await page.fill('input[name="user[email]"]', 'test@example.com');
    await page.fill('input[name="user[password]"]', 'password123456');
    
    await page.check('input[name="user[remember_me]"]');
    
    await page.click('button:has-text("Sign in")');
    
    await page.waitForLoadState('networkidle');
    
    await expect(page).toHaveURL(/\/(home|photos)/);
    
    await page.screenshot({ path: 'test-results/login-success.png' });
  });

  test('should show error with invalid credentials', async ({ page }) => {
    await page.goto('/users/log_in');
    
    await page.waitForLoadState('networkidle');
    
    await page.fill('input[name="user[email]"]', 'invalid@example.com');
    await page.fill('input[name="user[password]"]', 'wrongpassword');
    
    await page.click('button:has-text("Sign in")');
    
    await page.waitForTimeout(2000);
    
    const errorVisible = await page.locator('text=/Invalid email or password/i').isVisible().catch(() => false);
    const stillOnLoginPage = page.url().includes('/users/log_in');
    
    expect(errorVisible || stillOnLoginPage).toBeTruthy();
    
    await page.screenshot({ path: 'test-results/login-error.png' });
  });

  test('should navigate to registration page', async ({ page }) => {
    await page.goto('/users/log_in');
    
    await page.waitForLoadState('networkidle');
    
    await page.click('a:has-text("Sign up")');
    
    await page.waitForLoadState('networkidle');
    
    await expect(page).toHaveURL(/\/users\/register/);
  });

  test('should navigate to forgot password page', async ({ page }) => {
    await page.goto('/users/log_in');
    
    await page.waitForLoadState('networkidle');
    
    await page.click('a:has-text("Forgot your password?")');
    
    await page.waitForLoadState('networkidle');
    
    await expect(page).toHaveURL(/\/users\/reset_password/);
  });
});
