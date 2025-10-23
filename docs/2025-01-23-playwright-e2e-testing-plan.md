# Playwright E2E 测试计划

## 问题分析

### 核心需求
为 Vmemo 项目建立完整的端到端测试体系，覆盖核心功能流程：
1. **用户认证管理**：使用 Playwright storageState 管理登录状态
2. **照片上传功能**：测试手机端照片上传流程
3. **照片列表展示**：验证照片瀑布流展示
4. **照片详情查看**：测试照片详情页面功能
5. **备注更新功能**：测试照片备注编辑和保存

### 技术背景
- **Phoenix LiveView 应用**：使用 LiveView 进行实时交互
- **文件上传机制**：使用 `allow_upload/3` 和 `phx-hook="Phoenix.LiveFileUpload"`
- **认证系统**：基于 session token 的用户认证
- **响应式设计**：支持移动端和桌面端

### 当前状态分析
- 项目已有基础的 e2e 测试文件结构（已删除）
- 存在测试图片资源：`e2e/test-fixtures/test-image-1.png`, `test-image-2.png`
- 已有详细的文件上传测试失败问题分析文档
- 项目使用 Phoenix v1.8 和 LiveView

## 方案对比

### 方案一：完整 E2E 测试套件（推荐）
**优点**：
- 覆盖完整用户流程
- 真实模拟用户操作
- 能发现集成问题
- 提供回归测试保障

**缺点**：
- 测试执行时间较长
- 维护成本较高
- 需要稳定的测试环境

**实现方式**：
```typescript
// 使用 storageState 管理认证
// 模拟真实用户交互
// 覆盖所有核心功能流程
```

### 方案二：关键路径测试
**优点**：
- 测试执行快速
- 维护成本低
- 专注核心功能

**缺点**：
- 覆盖范围有限
- 可能遗漏边缘情况
- 集成问题发现较晚

### 方案三：混合测试策略
**优点**：
- 平衡覆盖度和效率
- 灵活调整测试范围
- 适合不同阶段需求

**缺点**：
- 策略复杂度较高
- 需要明确测试边界

## 技术选型

### 推荐方案：完整 E2E 测试套件
选择方案一，原因：
1. **业务价值高**：照片管理是核心功能，需要完整测试覆盖
2. **技术可行性**：已有详细的问题分析和解决方案
3. **长期维护**：建立标准化的测试流程

### 技术栈
- **Playwright**：现代化的 E2E 测试框架
- **TypeScript**：类型安全的测试代码
- **pnpm**：高效的包管理工具
- **storageState**：认证状态管理

## 架构设计

### 测试结构设计
```
e2e/
├── playwright.config.ts          # Playwright 配置
├── package.json                  # 依赖管理
├── tests/
│   ├── auth.setup.ts            # 认证设置
│   ├── photo-upload.spec.ts      # 照片上传测试
│   ├── photo-list.spec.ts        # 照片列表测试
│   ├── photo-detail.spec.ts      # 照片详情测试
│   └── photo-note.spec.ts        # 备注更新测试
├── fixtures/
│   ├── test-image-1.png         # 测试图片1
│   └── test-image-2.png         # 测试图片2
└── utils/
    ├── auth.ts                   # 认证工具
    ├── selectors.ts              # 选择器定义
    └── helpers.ts                # 测试辅助函数
```

### 认证管理设计
```typescript
// auth.setup.ts - 认证设置
import { test as setup } from '@playwright/test';

const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  await page.goto('/users/log_in');
  await page.fill('input[name="user[email]"]', 'test@example.com');
  await page.fill('input[name="user[password]"]', 'password123');
  await page.click('button[type="submit"]');
  await page.waitForURL('/home');
  await page.context().storageState({ path: authFile });
});
```

### 测试流程设计
```
1. 认证设置阶段
   ├── 用户登录
   ├── 保存 storageState
   └── 验证登录状态

2. 照片上传测试
   ├── 导航到上传页面
   ├── 触发文件选择器
   ├── 选择测试图片
   ├── 填写备注信息
   ├── 提交上传
   └── 验证上传成功

3. 照片列表测试
   ├── 导航到照片列表
   ├── 验证瀑布流展示
   ├── 测试加载更多
   └── 验证搜索功能

4. 照片详情测试
   ├── 点击照片进入详情
   ├── 验证图片显示
   ├── 验证相似照片
   └── 验证备注信息

5. 备注更新测试
   ├── 进入编辑模式
   ├── 修改备注内容
   ├── 保存更改
   └── 验证更新成功
```

### 关键测试点
1. **文件上传**：使用文件选择器触发 LiveView 事件
2. **认证状态**：使用 storageState 保持登录状态
3. **响应式设计**：测试移动端和桌面端适配
4. **异步操作**：正确处理 LiveView 的异步更新
5. **错误处理**：测试各种错误场景

## 风险评估

### 技术风险
1. **LiveView 兼容性**：不同版本的 LiveView 可能有不同的行为
2. **文件上传稳定性**：网络问题可能导致上传失败
3. **认证状态失效**：session 过期可能导致测试失败
4. **浏览器兼容性**：不同浏览器的行为差异

### 缓解措施
1. **版本锁定**：在 package.json 中锁定 Playwright 版本
2. **重试机制**：为关键操作实现智能重试
3. **超时设置**：为异步操作设置合理的超时时间
4. **多浏览器测试**：在 Chrome、Firefox、Safari 中测试

### 业务风险
1. **测试数据污染**：测试可能影响生产数据
2. **测试环境不稳定**：开发环境变化可能导致测试失败
3. **UI 变化影响**：界面更新可能导致选择器失效

### 缓解措施
1. **测试数据隔离**：使用专门的测试用户和数据
2. **环境配置**：建立稳定的测试环境
3. **选择器策略**：使用稳定的选择器策略

## 实施计划

### 阶段一：环境搭建（1-2天）
- [ ] 初始化 Playwright 项目
- [ ] 配置 pnpm 依赖管理
- [ ] 设置基础配置文件
- [ ] 创建测试目录结构

### 阶段二：认证管理（1天）
- [ ] 实现 storageState 认证设置
- [ ] 创建认证工具函数
- [ ] 测试认证状态持久化
- [ ] 验证登录流程

### 阶段三：核心功能测试（3-4天）
- [ ] 照片上传测试实现
- [ ] 照片列表测试实现
- [ ] 照片详情测试实现
- [ ] 备注更新测试实现

### 阶段四：优化完善（1-2天）
- [ ] 错误处理和重试机制
- [ ] 测试数据管理
- [ ] 性能优化
- [ ] 文档完善

### 阶段五：CI/CD 集成（1天）
- [ ] GitHub Actions 配置
- [ ] 测试报告生成
- [ ] 失败通知设置
- [ ] 部署流程集成

## 具体实现细节

### 1. 项目初始化
```bash
# 使用 pnpm 初始化项目
pnpm init

# 安装 Playwright
pnpm add -D @playwright/test

# 安装浏览器
pnpm exec playwright install
```

### 2. Playwright 配置
```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:4000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
      dependencies: ['setup'],
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
      dependencies: ['setup'],
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
      dependencies: ['setup'],
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
      dependencies: ['setup'],
    },
  ],
});
```

### 3. 认证设置
```typescript
// tests/auth.setup.ts
import { test as setup } from '@playwright/test';

const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  await page.goto('/users/log_in');

  // 填写登录表单
  await page.fill('input[name="user[email]"]', process.env.TEST_USER_EMAIL || 'test@vmemo.app');
  await page.fill('input[name="user[password]"]', process.env.TEST_USER_PASSWORD || 'password123');

  // 提交登录
  await page.click('button[type="submit"]');

  // 等待登录成功
  await page.waitForURL('/home');

  // 保存认证状态
  await page.context().storageState({ path: authFile });
});
```

### 4. 照片上传测试
```typescript
// tests/photo-upload.spec.ts
import { test, expect } from '@playwright/test';

test.describe('照片上传', () => {
  test('应该能够成功上传照片', async ({ page }) => {
    await page.goto('/upload');

    // 等待上传区域可见
    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"]');

    // 触发文件选择器
    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('label[for*="photos"]');
    const fileChooser = await fileChooserPromise;

    // 选择测试图片
    await fileChooser.setFiles('e2e/fixtures/test-image-1.png');

    // 等待上传进度
    await page.waitForSelector('[data-phx-hook="Phoenix.LiveFileUpload"] .phx-file-upload-progress');

    // 填写备注
    await page.fill('textarea[name="note"]', '测试照片备注');

    // 提交表单
    await page.click('button[type="submit"]');

    // 验证上传成功
    await expect(page).toHaveURL(/\/photos\/\d+/);
    await expect(page.locator('text=Photos uploaded successfully')).toBeVisible();
  });
});
```

### 5. 照片列表测试
```typescript
// tests/photo-list.spec.ts
import { test, expect } from '@playwright/test';

test.describe('照片列表', () => {
  test('应该能够显示照片列表', async ({ page }) => {
    await page.goto('/photos');

    // 验证页面标题
    await expect(page.locator('h1')).toContainText('Photos');

    // 验证瀑布流组件
    await expect(page.locator('[data-phx-hook="Waterfall"]')).toBeVisible();

    // 验证照片卡片
    const photoCards = page.locator('.photo-card');
    await expect(photoCards).toHaveCount.greaterThan(0);
  });

  test('应该能够加载更多照片', async ({ page }) => {
    await page.goto('/photos');

    // 滚动到底部触发加载更多
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));

    // 等待加载更多按钮
    await page.waitForSelector('button:has-text("Load More")');

    // 点击加载更多
    await page.click('button:has-text("Load More")');

    // 验证新照片加载
    await expect(page.locator('.photo-card')).toHaveCount.greaterThan(5);
  });
});
```

### 6. 照片详情测试
```typescript
// tests/photo-detail.spec.ts
import { test, expect } from '@playwright/test';

test.describe('照片详情', () => {
  test('应该能够查看照片详情', async ({ page }) => {
    // 先上传一张照片
    await page.goto('/upload');
    // ... 上传流程 ...

    // 点击照片进入详情
    await page.click('.photo-card:first-child');

    // 验证详情页面
    await expect(page.locator('img[alt*="测试照片"]')).toBeVisible();

    // 验证相似照片
    await expect(page.locator('text=Similar photos')).toBeVisible();

    // 验证备注信息
    await expect(page.locator('text=References')).toBeVisible();
  });

  test('应该能够删除照片', async ({ page }) => {
    await page.goto('/photos/1');

    // 悬停显示删除按钮
    await page.hover('figure.group');

    // 点击删除按钮
    await page.click('button[aria-label="delete"]');

    // 确认删除
    await page.click('button:has-text("Yes")');

    // 验证跳转到照片列表
    await expect(page).toHaveURL('/photos');
    await expect(page.locator('text=Deleted')).toBeVisible();
  });
});
```

### 7. 备注更新测试
```typescript
// tests/photo-note.spec.ts
import { test, expect } from '@playwright/test';

test.describe('备注更新', () => {
  test('应该能够更新照片备注', async ({ page }) => {
    await page.goto('/photos/1?action=edit');

    // 验证编辑表单可见
    await expect(page.locator('form')).toBeVisible();

    // 修改备注内容
    await page.fill('textarea[name="note"]', '更新后的备注内容');

    // 保存更改
    await page.click('button:has-text("Save")');

    // 验证保存成功
    await expect(page.locator('text=Saved')).toBeVisible();

    // 验证备注已更新
    await expect(page.locator('textarea[name="note"]')).toHaveValue('更新后的备注内容');
  });

  test('应该能够生成 AI 描述', async ({ page }) => {
    await page.goto('/photos/1');

    // 点击 AI 描述按钮
    await page.click('button[aria-label="AI trained"]');

    // 等待描述生成
    await expect(page.locator('text=Description generated')).toBeVisible();

    // 验证描述字段有内容
    await expect(page.locator('textarea[name="_gen_description"]')).not.toBeEmpty();
  });
});
```

## 预期成果

### 短期目标
- 建立完整的 E2E 测试框架
- 实现核心功能的自动化测试
- 提高代码质量和稳定性
- 减少手动测试工作量

### 长期目标
- 建立持续集成测试流程
- 提高测试覆盖率和质量
- 建立测试最佳实践
- 支持快速迭代和部署

## 总结

本计划为 Vmemo 项目建立了完整的 Playwright E2E 测试体系，通过 storageState 管理认证状态，覆盖照片上传、列表展示、详情查看和备注更新等核心功能。

关键成功因素：
1. **技术方案**：使用 Playwright + storageState + pnpm 的现代化技术栈
2. **测试策略**：基于真实用户流程的端到端测试
3. **实施计划**：分阶段实施，逐步完善
4. **风险控制**：充分的风险评估和缓解措施

通过实施本计划，将显著提高项目的测试覆盖率和代码质量，为项目的长期发展提供有力保障。
