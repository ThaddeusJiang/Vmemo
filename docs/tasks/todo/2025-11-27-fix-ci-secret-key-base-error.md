# 2025-11-27 修复 CI 失败：Secret Key Base 错误

## 任务目标

修复 GitHub Actions CI 中 55 个测试失败的问题，错误信息为：

```
Secret for `authentication.tokens.signing_secret` on the `Vmemo.Account.AshUser` resource returned an invalid value. Expected an `:ok` tuple, or `:error`.
```

## 计划阶段

### 问题分析

- **错误位置**：`lib/vmemo/account/ash_user.ex:130` 的 `get_signing_secret/2` 函数
- **错误原因**：函数返回字符串值，但 AshAuthentication 期望返回 `{:ok, secret}` 或 `:error` 元组
- **影响范围**：所有使用 JWT token 的测试用例（55 个测试失败）

### 技术方案

修改 `get_signing_secret/2` 函数，使其返回正确的格式：

- 如果配置存在：返回 `{:ok, secret}`
- 如果配置不存在：返回 `:error`

## 执行记录

### 阶段一：修复返回值格式

- **时间**：2025-11-27
- **操作**：修改 `get_signing_secret/2` 函数返回值格式
- **变更**：

  ```elixir
  # 修改前
  defp get_signing_secret(_resource, _opts) do
    Application.get_env(:vmemo, :secret_key_base) ||
      raise "SECRET_KEY_BASE is not configured"
  end

  # 修改后
  defp get_signing_secret(_resource, _opts) do
    case Application.get_env(:vmemo, :secret_key_base) do
      nil -> :error
      secret -> {:ok, secret}
    end
  end
  ```

- **结果**：修复完成

## 测试记录

- [x] 单个测试验证 - ✅ 通过
  ```bash
  MIX_ENV=test mix test test/vmemo/account_test.exs:246
  ```
- [x] 完整测试套件 - ✅ 通过
  ```bash
  MIX_ENV=test mix test
  # 163 tests, 0 failures
  ```
- [x] Linter 检查 - ✅ 无错误

## 总结

- ✅ 成功修复 `get_signing_secret/2` 函数的返回值格式
- ✅ 所有 163 个测试通过，包括之前失败的 55 个测试
- ✅ 符合 AshAuthentication 的 API 要求
- ✅ 无 linter 错误

### 技术细节

AshAuthentication 的 `signing_secret` 配置期望函数返回：

- `{:ok, secret}` - 成功获取密钥
- `:error` - 无法获取密钥

之前的实现直接返回字符串或抛出异常，不符合 API 要求。
