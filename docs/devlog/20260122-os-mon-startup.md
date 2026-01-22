# 20260122 os_mon startup

## 背景

- 访问 `/dev/dashboard/os_mon` 页面出现 `cpu_sup`/`disksup`/`memsup` 未启动的警告

## 变更

- 在应用启动时显式启动 `:os_mon`，确保 LiveDashboard 可用

## 验证

- 未运行（按需在本地确认）
