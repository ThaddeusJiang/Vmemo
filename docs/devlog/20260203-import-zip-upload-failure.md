# Import ZIP upload failure

## 背景
- 在 AshAdmin 的 ImportRequest 创建页面上传 ZIP 时，表单返回 “Failed to read uploaded ZIP file”。

## 处理
- 在 ImportRequest 的 `import` action 中增加对 `Ash.Type.File.path/1` 不支持场景的兜底处理。
- 当无法直接读取路径时，改为通过 `Ash.Type.File.open/2` 以流式方式复制文件到临时目录。
- 继续保留 `source_filename` 与 `import_zip_path` 的写入逻辑。

## 影响
- AshAdmin 与非路径实现的文件上传也能正确读取 ZIP 并启动导入任务。

## 验证
- 未运行测试（按规范）。
- 建议在 Admin Import 页面重新上传 `vmemo-users-export.zip` 验证。
