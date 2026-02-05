# 移除 ImportRequest 的 metadata 表单字段

## 背景
- ImportRequest 的 admin form 只需要上传 ZIP，但 AshAdmin 默认渲染 `accept` 字段，导致出现 `metadata`。

## 处理
- 将 `ImportRequest` 的 `:import` action 的 `accept` 列表改为空，仅保留 `import_zip` 参数。

## 影响
- Admin Import 页面只显示 ZIP 上传输入。

## 验证
- 未运行测试（按规范）。
- 建议打开 Admin Import 页面确认 `metadata` 字段消失。
