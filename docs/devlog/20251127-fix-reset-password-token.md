# 修复密码重置链接无效问题

## 问题描述

用户点击 forgot password 发送邮件后，访问重置链接总是出现 "Reset password link is invalid or it has expired." 错误。

## 问题分析

1. `deliver_ash_user_reset_password_instructions` 使用 `AshAuthentication.Jwt.token_for_user` 生成 JWT token
2. 但生成的 token **没有被保存到数据库** (`ash_user_tokens` 表)
3. `verify_reset_password_token` 验证时会检查 token 是否存在于数据库中
4. 由于 token 不存在，验证失败，返回 `:token_not_found` 错误

## 解决方案

### 1. 修改 token 存储逻辑 (`lib/vmemo/account.ex`)

在生成 token 后，使用 `AshAuthentication.TokenResource.Actions.store_token` 保存到数据库，并更新 `ash_user_id` 字段：

```elixir
def deliver_ash_user_reset_password_instructions(%AshUser{} = ash_user, reset_password_url_fun)
    when is_function(reset_password_url_fun, 1) do
  case AshAuthentication.Jwt.token_for_user(ash_user) do
    {:ok, token, _claims} ->
      store_reset_password_token(ash_user, token)
      reset_url = reset_password_url_fun.(token)
      Vmemo.Account.UserNotifier.deliver_reset_password_instructions(ash_user, reset_url)

    _ ->
      {:error, :token_generation_failed}
  end
end

defp store_reset_password_token(ash_user, token) do
  context_patch = %{
    private: %{ash_authentication?: true}
  }

  with :ok <-
         AshAuthentication.TokenResource.Actions.store_token(
           Vmemo.Account.AshUserToken,
           %{"token" => token, "purpose" => "reset_password"},
           context: context_patch
         ),
       {:ok, %{"jti" => jti}} <- AshAuthentication.Jwt.peek(token),
       {:ok, token_record} <- Ash.get(Vmemo.Account.AshUserToken, jti) do
    Ash.update(token_record, %{ash_user_id: ash_user.id}, action: :update_user_id)
  end
end
```

**关键点**：

- 使用 `store_token` 保存 token 到数据库
- 从 JWT 中提取 `jti` (JWT ID)
- 获取 token 记录并更新 `ash_user_id` 字段，建立与用户的关联

### 2. 修改 AshUserToken 资源 (`lib/vmemo/account/ash_user_token.ex`)

将自定义字段设为 `allow_nil?: true`，因为标准的 `store_token` action 不会填充这些字段：

```elixir
attribute :aud, :string, allow_nil?: true, public?: true
attribute :exp, :utc_datetime, allow_nil?: true, public?: true
attribute :iss, :string, allow_nil?: true, public?: true
attribute :sub, :string, allow_nil?: true, public?: true
attribute :typ, :string, allow_nil?: true, public?: true
```

### 3. 数据库迁移

创建迁移允许这些字段为 null：

```elixir
alter table(:ash_user_tokens) do
  modify :aud, :text, null: true
  modify :exp, :utc_datetime, null: true
  modify :iss, :text, null: true
  modify :sub, :text, null: true
  modify :typ, :text, null: true
end
```

## 验证

1. 发送密码重置邮件 ✓
2. Token 成功保存到 `ash_user_tokens` 表 ✓
3. 访问重置链接显示密码重置表单 ✓
4. 成功重置密码并跳转到登录页 ✓
