# 20260129-add-zeabur-dependencies

## 变更
- 为 Zeabur 模板中的 Vmemo 服务添加 dependencies：postgresql、typesense。

## 原因
- 明确运行时依赖，避免服务启动顺序问题。

## 影响
- 仅影响部署模板配置，不改动应用代码逻辑。
