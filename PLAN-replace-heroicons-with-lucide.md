# 计划书：将 Heroicons 替换为 Lucide

## 项目背景

当前 Vmemo.app 使用 Heroicons 作为图标库，通过 Tailwind CSS 插件将 SVG 图标嵌入到 CSS 中。现需要将其替换为 Lucide 图标库，并遵循 Phoenix 标准做法。

## 当前实现分析

### 1. Heroicons 依赖
- **mix.exs**: 通过 GitHub 直接引入 heroicons (v2.1.1)
- **deps/heroicons**: 存储在 deps 目录中的 SVG 文件

### 2. Tailwind 插件配置
- **assets/tailwind.config.js**: 自定义插件读取 `deps/heroicons/optimized` 目录
- 支持四种样式：outline (默认), solid, mini, micro
- 使用 CSS mask 技术将 SVG 转换为可着色的图标

### 3. 图标组件
- **lib/vmemo_web/components/core_components.ex**: `icon/1` 函数
- 使用方式：`<.icon name="hero-x-mark-solid" class="h-4 w-4" />`
- 渲染为：`<span class="hero-x-mark-solid h-4 w-4" />`

### 4. 当前使用的图标
根据代码搜索，当前使用的 heroicons 包括：
- `hero-x-mark-solid` (关闭按钮)
- `hero-information-circle-mini` (信息提示)
- `hero-exclamation-circle-mini` (错误提示)
- `hero-arrow-path` (加载动画)
- `hero-arrow-left-solid` (返回按钮)

## 目标方案

### 1. 不使用 npm 安装依赖
遵循 Phoenix 标准做法，使用 CDN 方式引入 Lucide：
- 在 `root.html.heex` 中通过 `<script>` 标签引入 Lucide ESM 版本
- 使用 `lucide.createIcons()` 初始化图标

### 2. 直接在 HTML 中使用
- 删除 `icon/1` 组件
- 使用 `<i data-lucide="volume-2" class="my-class"></i>` 格式
- 在页面加载时通过 JavaScript 初始化图标

### 3. 图标映射关系
| Heroicons | Lucide |
|-----------|--------|
| hero-x-mark-solid | x |
| hero-information-circle-mini | info |
| hero-exclamation-circle-mini | alert-circle |
| hero-arrow-path | loader-circle |
| hero-arrow-left-solid | arrow-left |

## 实施步骤

### Phase 1: 准备工作
1. ✅ 分析当前代码结构
2. ✅ 确定所有使用的图标
3. ✅ 制定替换方案

### Phase 2: 引入 Lucide
1. 在 `lib/vmemo_web/components/layouts/root.html.heex` 中添加 Lucide CDN
2. 在 `assets/js/app.js` 中添加 Lucide 初始化代码

### Phase 3: 替换图标使用
1. 更新 `core_components.ex` 中的所有 `<.icon>` 调用
2. 删除 `icon/1` 函数定义
3. 更新文档注释

### Phase 4: 清理 Heroicons
1. 从 `mix.exs` 中移除 heroicons 依赖
2. 从 `assets/tailwind.config.js` 中移除 heroicons 插件
3. 运行 `mix deps.clean heroicons --unlock`

### Phase 5: 测试与验证
1. 运行 `mix deps.get` 更新依赖
2. 运行 `mix assets.build` 重新构建资源
3. 启动开发服务器验证图标显示
4. 检查所有页面的图标是否正常

### Phase 6: 提交代码
1. 创建 Git 分支
2. 提交所有更改
3. 创建 Pull Request
4. 等待 CI 检查通过

## 技术细节

### Lucide CDN 引入方式
```html
<script type="module">
  import { createIcons } from 'https://unpkg.com/lucide@latest/dist/esm/lucide.js';
  
  // 初始化图标
  createIcons();
  
  // 监听 LiveView 更新
  window.addEventListener('phx:page-loading-stop', () => {
    createIcons();
  });
</script>
```

### 图标使用方式
```html
<!-- 旧方式 -->
<.icon name="hero-x-mark-solid" class="h-4 w-4" />

<!-- 新方式 -->
<i data-lucide="x" class="h-4 w-4"></i>
```

## 风险评估

### 低风险
- Lucide 是成熟的图标库，有良好的文档和社区支持
- CDN 方式简单可靠，无需构建步骤
- 图标数量少，替换工作量可控

### 需要注意
- LiveView 动态更新时需要重新初始化图标
- 确保所有图标都有对应的 Lucide 版本
- CSS 类名需要调整以适应新的图标系统

## 预期结果

1. 完全移除 Heroicons 依赖
2. 使用 Lucide 图标库，通过 CDN 引入
3. 所有图标正常显示，样式保持一致
4. 代码更简洁，符合 Phoenix 标准做法
5. 构建速度可能略有提升（减少了 Tailwind 插件处理）

## 工作记录

将在实施过程中记录所有更改和遇到的问题。
