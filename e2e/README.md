# Vmemo E2E Tests with Playwright

This directory contains end-to-end tests for the Vmemo application using Playwright.

## Features

- ✅ Login functionality tests
- ✅ Photo upload tests (single and multiple images)
- ✅ Video recording of all test runs
- ✅ Screenshots on key actions
- ✅ Automatic test report generation

## Prerequisites

- Node.js (v16 or higher)
- Running Vmemo application (or use the built-in webServer config)
- Test user account with credentials:
  - Email: `test@example.com`
  - Password: `password123456`

## Installation

```bash
cd e2e
npm install
npx playwright install chromium
```

## Running Tests

### Run all tests
```bash
npm test
```

### Run tests in headed mode (see browser)
```bash
npm run test:headed
```

### Run tests in UI mode (interactive)
```bash
npm run test:ui
```

### Run tests in debug mode
```bash
npm run test:debug
```

### Run specific test file
```bash
npx playwright test tests/login.spec.js
npx playwright test tests/upload.spec.js
```

## Test Structure

```
e2e/
├── tests/
│   ├── login.spec.js       # Login functionality tests
│   └── upload.spec.js      # Photo upload tests
├── test-fixtures/
│   ├── test-image-1.png    # Test image for upload
│   └── test-image-2.png    # Test image for upload
├── playwright.config.js    # Playwright configuration
├── package.json
└── README.md
```

## Video Recordings

All test runs are automatically recorded as videos. After running tests, you can find:

- **Videos**: `test-results/` directory (one video per test)
- **Screenshots**: `test-results/` directory
- **HTML Report**: Run `npx playwright show-report` to view detailed results

## Configuration

The Playwright configuration (`playwright.config.js`) includes:

- **Video Recording**: Enabled for all tests (`video: 'on'`)
- **Screenshots**: Taken on key actions (`screenshot: 'on'`)
- **Base URL**: `http://localhost:4000` (configurable via `BASE_URL` env var)
- **Web Server**: Automatically starts the Phoenix server if not running

## Test Scenarios

### Login Tests
1. ✅ Successful login with valid credentials
2. ✅ Error handling with invalid credentials
3. ✅ Navigation to registration page
4. ✅ Navigation to forgot password page

### Upload Tests
1. ✅ Upload single image with note
2. ✅ Upload multiple images with note
3. ✅ Cancel image upload
4. ✅ Verify form elements display correctly

## Customization

### Change test user credentials
Edit the `login()` helper function in `tests/upload.spec.js` and the credentials in `tests/login.spec.js`.

### Change base URL
Set the `BASE_URL` environment variable:
```bash
BASE_URL=http://localhost:4000 npm test
```

### Disable video recording
Edit `playwright.config.js` and change:
```javascript
video: 'retain-on-failure'  // Only record failed tests
// or
video: 'off'  // Disable video recording
```

## Troubleshooting

### Tests fail with "Cannot find element"
- Ensure the application is running on `http://localhost:4000`
- Check that the test user exists in the database
- Verify the selectors match your application's HTML structure

### Video files not generated
- Check the `test-results/` directory
- Ensure `video: 'on'` is set in `playwright.config.js`
- Videos are saved even if tests pass

### Application not starting
- Manually start the application: `cd .. && docker compose up -d && mix phx.server`
- Or disable the webServer config in `playwright.config.js`

## CI/CD Integration

To run tests in CI/CD pipelines:

```yaml
- name: Install dependencies
  run: cd e2e && npm install

- name: Install Playwright browsers
  run: cd e2e && npx playwright install --with-deps chromium

- name: Run tests
  run: cd e2e && npm test

- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: playwright-results
    path: e2e/test-results/
```

## License

Same as the main Vmemo project.
