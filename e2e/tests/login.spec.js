const { test, expect } = require('@playwright/test');

test.describe('User Login', () => {
  test('should successfully login with valid credentials', async ({ page }) => {
    await page.goto('/users/log_in');
    
    await expect(page.getByText('Sign in to account')).toBeVisible();
    
    await page.getByLabel('Email').fill('test@example.com');
    await page.getByLabel('Password').fill('password123456');
    
    await page.getByLabel('Keep me logged in').check();
    
    await page.getByRole('button', { name: 'Sign in' }).click();
    
    await expect(page).toHaveURL(/\/(home|photos)/);
    
    await page.screenshot({ path: 'test-results/login-success.png' });
  });

  test('should show error with invalid credentials', async ({ page }) => {
    await page.goto('/users/log_in');
    
    await page.getByLabel('Email').fill('invalid@example.com');
    await page.getByLabel('Password').fill('wrongpassword');
    
    await page.getByRole('button', { name: 'Sign in' }).click();
    
    await expect(page).toHaveURL(/\/users\/log_in/);
    
    await page.screenshot({ path: 'test-results/login-error.png' });
  });

  test('should navigate to registration page', async ({ page }) => {
    await page.goto('/users/log_in');
    
    await page.getByRole('link', { name: 'Sign up' }).click();
    
    await expect(page).toHaveURL(/\/users\/register/);
  });

  test('should navigate to forgot password page', async ({ page }) => {
    await page.goto('/users/log_in');
    
    await page.getByRole('link', { name: 'Forgot your password?' }).click();
    
    await expect(page).toHaveURL(/\/users\/reset_password/);
  });
});
