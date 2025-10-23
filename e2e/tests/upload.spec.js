const { test, expect } = require('@playwright/test');
const path = require('path');

test.describe('Photo Upload', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/users/log_in');
    await page.getByLabel('Email').fill('test@example.com');
    await page.getByLabel('Password').fill('password123456');
    await page.getByLabel('Keep me logged in').check();
    await page.getByRole('button', { name: 'Sign in' }).click();
    await expect(page).toHaveURL(/\/(home|photos)/);
  });

  test('should upload single image successfully', async ({ page }) => {
    await page.goto('/upload');
    
    await expect(page.getByText('Drag and drop images here or click to upload')).toBeVisible();
    
    const fileInput = page.locator('input[type="file"]');
    const testImagePath = path.join(__dirname, '../test-fixtures/test-image-1.png');
    await fileInput.setInputFiles(testImagePath);
    
    await expect(page.locator('.upload-entry').first()).toBeVisible({ timeout: 10000 });
    
    await page.getByLabel('Note').fill('Test upload from Playwright');
    
    await page.screenshot({ path: 'test-results/upload-before-submit.png' });
    
    await page.getByRole('button', { name: 'Upload' }).click();
    
    await expect(page).toHaveURL(/\/photos/);
    
    await page.screenshot({ path: 'test-results/upload-success.png' });
  });

  test('should upload multiple images successfully', async ({ page }) => {
    await page.goto('/upload');
    
    const fileInput = page.locator('input[type="file"]');
    const testImage1Path = path.join(__dirname, '../test-fixtures/test-image-1.png');
    const testImage2Path = path.join(__dirname, '../test-fixtures/test-image-2.png');
    await fileInput.setInputFiles([testImage1Path, testImage2Path]);
    
    await expect(page.locator('.upload-entry')).toHaveCount(2);
    
    await page.getByLabel('Note').fill('Multiple images test from Playwright');
    
    await page.getByLabel('Is whole').check();
    
    await page.screenshot({ path: 'test-results/upload-multiple-before-submit.png' });
    
    await page.getByRole('button', { name: 'Upload' }).click();
    
    await expect(page).toHaveURL(/\/photos/);
    
    await page.screenshot({ path: 'test-results/upload-multiple-success.png' });
  });

  test('should cancel image upload', async ({ page }) => {
    await page.goto('/upload');
    
    const fileInput = page.locator('input[type="file"]');
    const testImagePath = path.join(__dirname, '../test-fixtures/test-image-1.png');
    await fileInput.setInputFiles(testImagePath);
    
    const uploadEntry = page.locator('.upload-entry').first();
    await expect(uploadEntry).toBeVisible();
    
    const cancelButton = uploadEntry.getByRole('button', { name: '×' });
    await cancelButton.click();
    
    await expect(uploadEntry).not.toBeVisible();
    
    await page.screenshot({ path: 'test-results/upload-cancel.png' });
  });

  test('should show upload form elements correctly', async ({ page }) => {
    await page.goto('/upload');
    
    await expect(page.getByText('Drag and drop images here or click to upload')).toBeVisible();
    await expect(page.locator('input[type="file"]')).toBeAttached();
    
    const fileInput = page.locator('input[type="file"]');
    const testImagePath = path.join(__dirname, '../test-fixtures/test-image-1.png');
    await fileInput.setInputFiles(testImagePath);
    
    await expect(page.getByLabel('Note')).toBeVisible();
    await expect(page.getByLabel('Is whole')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Upload' })).toBeVisible();
    
    await page.screenshot({ path: 'test-results/upload-form-elements.png' });
  });
});
