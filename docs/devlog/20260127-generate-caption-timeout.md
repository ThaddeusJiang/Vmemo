# 2026-01-27 generate caption timeout

## 背景
- 点击 Generate caption 后出现 Request timeout。
- 期望与其他 Moondream 调用一致，使用 Oban + PubSub 异步处理。

## 变更
- ProcessCaptionRequest 改为直接读取本地图片并调用 Moondream.caption，避免依赖 Typesense 的同步请求。
- 读取图片逻辑与 ProcessMoondreamRequest 对齐。

## 影响
- 生成 caption 的异步流程更稳定，减少超时源头。
- 失败时仍会在表单附近显示错误，并可 Retry。

## 后续
- 如仍有超时，考虑在 Moondream 请求侧调优超时或重试策略。
