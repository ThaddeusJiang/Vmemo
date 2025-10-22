const { test, expect } = require('@playwright/test');
const path = require('path');

test.describe('Photo Upload', () => {
  async function login(page) {
    await page.goto('/users/log_in');
    await page.waitForLoadState('networkidle');
    
    await page.fill('input[name="user[email]"]', 'test@example.com');
    await page.fill('input[name="user[password]"]', 'password123456');
    
    await page.click('button:has-text("Sign in")');
    await page.waitForLoadState('networkidle');
  }

  test('should upload single image successfully', async ({ page }) => {
    await login(page);
    
    await page.goto('/photos/upload');
    await page.waitForLoadState('networkidle');
    
    await expect(page.locator('text=Drag and drop images here or click to upload')).toBeVisible();
    
    const fileInput = page.locator('input[type="file"]');
    
    const testImagePath = path.join(__dirname, '../test-fixtures/test-image-1.png');
    await fileInput.setInputFiles(testImagePath);
    
    await page.waitForTimeout(1000);
    
    const uploadEntry = page.locator('.upload-entry').first();
    await expect(uploadEntry).toBeVisible();
    
    await page.fill('textarea[name="note"]', 'Test upload from Playwright');
    
    await page.screenshot({ path: 'test-results/upload-before-submit.png' });
    
    await page.click('button:has-text("Upload")');
    
    await page.waitForLoadState('networkidle');
    
    await expect(page).toHaveURL(/\/photos/);
    
    await page.screenshot({ path: 'test-results/upload-success.png' });
  });

  test('should upload multiple images successfully', async ({ page }) => {
    await login(page);
    
    await page.goto('/photos/upload');
    await page.waitForLoadState('networkidle');
    
    const fileInput = page.locator('input[type="file"]');
    
    const testImage1Path = path.join(__dirname, '../test-fixtures/test-image-1.png');
    const testImage2Path = path.join(__dirname, '../test-fixtures/test-image-2.png');
    await fileInput.setInputFiles([testImage1Path, testImage2Path]);
    
    await page.waitForTimeout(1500);
    
    const uploadEntries = page.locator('.upload-entry');
    await expect(uploadEntries).toHaveCount(2);
    
    await page.fill('textarea[name="note"]', 'Multiple images test from Playwright');
    
    await page.check('input[name="is_whole"]');
    
    await page.screenshot({ path: 'test-results/upload-multiple-before-submit.png' });
    
    await page.click('button:has-text("Upload")');
    
    await page.waitForLoadState('networkidle');
    
    await expect(page).toHaveURL(/\/photos/);
    
    await page.screenshot({ path: 'test-results/upload-multiple-success.png' });
  });

  test('should cancel image upload', async ({ page }) => {
    await login(page);
    
    await page.goto('/photos/upload');
    await page.waitForLoadState('networkidle');
    
    const fileInput = page.locator('input[type="file"]');
    
    const testImagePath = path.join(__dirname, '../test-fixtures/test-image-1.png');
    await fileInput.setInputFiles(testImagePath);
    
    await page.waitForTimeout(1000);
    
    const uploadEntry = page.locator('.upload-entry').first();
    await expect(uploadEntry).toBeVisible();
    
    const cancelButton = page.locator('.upload-entry button:has-text("×")').first();
    await cancelButton.click();
    
    await page.waitForTimeout(500);
    
    await expect(uploadEntry).not.toBeVisible();
    
    await page.screenshot({ path: 'test-results/upload-cancel.png' });
  });

  test('should show upload form elements correctly', async ({ page }) => {
    await login(page);
    
    await page.goto('/photos/upload');
    await page.waitForLoadState('networkidle');
    
    await expect(page.locator('text=Drag and drop images here or click to upload')).toBeVisible();
    await expect(page.locator('input[type="file"]')).toBeAttached();
    
    const fileInput = page.locator('input[type="file"]');
    const testImagePath = path.join(__dirname, '../test-fixtures/test-image-1.png');
    await fileInput.setInputFiles(testImagePath);
    
    await page.waitForTimeout(1000);
    
    await expect(page.locator('textarea[name="note"]')).toBeVisible();
    
    await expect(page.locator('input[name="is_whole"]')).toBeVisible();
    
    await expect(page.locator('button:has-text("Upload")')).toBeVisible();
    
    await page.screenshot({ path: 'test-results/upload-form-elements.png' });
  });
});
