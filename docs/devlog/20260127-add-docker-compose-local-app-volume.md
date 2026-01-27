# 20260127 add docker compose local app volume

## 变更
- 为 `docker-compose.local.yml` 的 app 增加 `./storage:/app/storage` volume

## 原因
- 容器内 `storage/v1` 需要与宿主机持久化目录保持一致
