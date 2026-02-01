# 2026-01-28 Align Zeabur standalone env order

## 目标
- 按 variables 顺序整理 Vmemo service 的 env 定义

## 变更
- 调整 standalone 模板 env 顺序以匹配 variables
- standalone 模板改为自动生成 ADMIN_TOKEN 与 SECRET_KEY_BASE，并保留 admin token 提示
- vmemo 模板移除可自动获取的 variables，仅保留需要用户填写的项
- vmemo 模板 env 顺序与 standalone 保持一致

## 备注
- PHX_SERVER 与 PHX_HOST 维持在变量相关项之后
