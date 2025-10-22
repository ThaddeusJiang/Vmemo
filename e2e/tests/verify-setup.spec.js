const { test, expect } = require('@playwright/test');

test.describe('Playwright Setup Verification', () => {
  test('should verify Playwright is working correctly', async ({ page }) => {
    await page.goto('https://example.com');
    
    await expect(page).toHaveTitle(/Example Domain/);
    
    await page.screenshot({ path: 'test-results/verify-setup.png' });
    
    console.log('✅ Playwright setup verified successfully!');
  });
});
