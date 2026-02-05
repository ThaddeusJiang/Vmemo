# 20260201 管理端导入改为上传 ZIP

## 目标

- AshAdmin 的 ImportRequest 创建入口使用 ZIP 上传，而不是填写文件名。

## 记录

- 为 ImportRequest 新增 `import` create action，使用 `Ash.Type.File` 参数接收 ZIP。
- 在 action 内复制上传文件到临时目录，并写入 `source_filename`。
- 通过 `create_actions` 只暴露 `import` 给 AshAdmin，避免出现手填文件名的表单。
- 复用 Oban worker 触发导入任务。
