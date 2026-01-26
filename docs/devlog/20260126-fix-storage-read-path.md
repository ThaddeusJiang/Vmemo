# 20260126 fix storage read path

## 变更
- 读取图片统一从 `storage/v1` 获取（保持相对路径）
- AI 描述生成读取路径继续走 `storage/v1`

## 影响
- URL 仍保持 `/storage/...`，读取路径不引入 `/app/storage`

## 后续
- 如果需要我可以补一个配置项来控制存储根路径
