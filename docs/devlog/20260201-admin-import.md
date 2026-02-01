# 20260201 管理端导入导出 ZIP

## 目标

- 增加 import 功能，支持导入 tag `20260120` 导出的 ZIP 数据并写入系统。

## 记录

- 使用 LiveView 内置上传 ZIP。
- 导入过程使用 Oban + PubSub 异步执行。
- 写入 users / photos / notes / photos_notes。
- ZIP 内若包含文件，复制到 `storage/v1`。

## 计划

- 新增 Admin Import Request 资源与迁移。
- 实现 ZIP 解析与导入逻辑、Oban worker 与 PubSub 通知。
- 增加管理端 LiveView 页面与路由。
- 给 AshUser / Photo / Note 增加 import action。
