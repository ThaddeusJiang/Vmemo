---
name: choicejs-skill
description: 基于 Choices.js 官方文档实现可维护、可主题化、无闪烁的 Tag/Select 输入 UI，适用于 Phoenix LiveView 与常规前端项目。
version: 1.0.0
argument-hint: "[implement|polish|audit]"
---

# Choices.js UI Skill

本 skill 用于指导 agent 按 [Choices.js 官方文档](https://github.com/Choices-js/Choices) 实现和优化 UI，重点是：
- 使用官方 `--choices-*` CSS custom properties
- 与项目设计系统（如 daisyUI）对齐
- 保证可输入、无重复渲染、无页面闪烁

## 触发场景
- 用户要求“用 Choices.js 做 tags/select 输入”
- 用户要求“按 CSS custom properties 做主题”
- 出现 `Choices` UI 异常：不可输入、样式割裂、重复 chips、初始化闪烁

## 执行流程

### 1) 先定义全局主题变量（必须）
把基础变量定义到 `:root`（如需深色主题，再覆盖 `[data-theme="dark"]` 或 `@media (prefers-color-scheme: dark)`）：

- 颜色相关：`--choices-bg-color` `--choices-bg-color-dropdown` `--choices-keyline-color` `--choices-primary-color` `--choices-item-color` `--choices-highlighted-color`
- 尺寸相关：`--choices-border-radius` `--choices-border-radius-item` `--choices-input-height` `--choices-inner-padding`
- 交互相关：`--choices-button-opacity` `--choices-button-opacity-hover` `--choices-z-index`

原则：
- 全局默认在 `:root`，组件差异只在局部覆盖
- 不要把全部变量只写在组件局部，否则 devtools 常见未定义提示

### 2) 初始化策略（避免闪烁/重复）
- 原始 `<select multiple>` 先隐藏（如 `style="display:none"`）
- `mounted` 初始化 Choices
- `updated` 先 `destroy()` 再重建，避免重复实例
- 初始化成功后打 `is-ready` 类，再显示容器（`visibility: visible`）

### 3) 与 LiveView 事件同步
- `addItem` 推送 `add-tag`
- `removeItem` 推送 `remove-tag`
- 使用 `suppress` 标记避免回写时事件环路
- 从 DOM 反向同步 selected options 到 Choices 实例

### 4) 样式对齐策略
- 目标是“看起来像项目原生 input/badge”，不是“Choices 默认皮肤”
- 优先调变量，不要大量硬编码覆盖内部类
- 组件局部仅处理结构差异（例如 dropdown 阴影、局部间距）

## 推荐最小配置（JS）
```js
new Choices(el, {
  removeItemButton: true,
  duplicateItemsAllowed: false,
  shouldSort: false,
  searchEnabled: true,
  placeholder: true,
  noResultsText: "",
  noChoicesText: "",
  itemSelectText: "",
  addItems: true,
  addChoices: true,
  delimiter: ",",
})
```

## 验收 checklist
- 能输入新 tag
- 能选择已有 tag
- 删除 tag 正常
- 不出现重复 tag UI
- 页面加载无闪烁（FOUC）
- 深浅色主题都可读
- devtools 不出现核心 `--choices-*` 未定义告警

## 常见故障与修复
- 问题：不可输入  
  修复：检查 `searchEnabled/addItems/addChoices`、input 是否被遮挡、`updated` 是否反复 destroy 导致焦点丢失

- 问题：样式与系统不一致  
  修复：先统一 `:root` 变量，再做局部微调；禁止直接复制 demo 样式

- 问题：初始化闪烁  
  修复：使用 `visibility: hidden -> .is-ready { visibility: visible }`
