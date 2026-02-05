# 修复 ImportRequest 编译错误

## 背景
- 启动 Phoenix 服务时，`Vmemo.Admin.ImportRequest` 报错：`require_atomic?/1` 未定义。
- 该选项不适用于 create action。

## 处理
- 移除 `create :import` 中的 `require_atomic? false`。

## 影响范围
- `Vmemo.Admin.ImportRequest` 的 `import` action 编译通过。

## 测试
- 未运行（按要求不执行 build/start）。
