defmodule Vmemo.Seeds.TestUsers do
  @moduledoc """
  Creates test users for development and testing environments.
  """

  alias Vmemo.Account
  alias Vmemo.AshRepo

  def run do
    # 创建 test 用户
    user = create_test_user()

    # 为 test 用户创建 API token
    create_test_api_token(user)
  end

  defp create_test_user do
    email = "test@mail.com"
    password = "password123456"

    case Account.get_ash_user_by_email(email) do
      nil ->
        case Account.register_user(%{email: email, password: password}) do
          {:ok, user} ->
            # 确认用户 - 使用 raw SQL 更新 confirmed_at
            now = DateTime.utc_now() |> DateTime.truncate(:second)
            
            case AshRepo.query("UPDATE ash_users SET confirmed_at = $1 WHERE id = $2", [now, user.id]) do
              {:ok, _} ->
                IO.puts("✓ Created and confirmed user: #{email}")
                # 重新加载用户以获取更新后的 confirmed_at
                Account.get_ash_user_by_email(email)
              
              {:error, error} ->
                IO.puts("⚠ User created but confirmation failed: #{inspect(error)}")
                user
            end

          {:error, changeset} ->
            IO.puts("✗ Failed to create user #{email}: #{inspect(changeset.errors)}")
            nil
        end

      existing_user ->
        IO.puts("→ User already exists: #{email}")
        existing_user
    end
  end

  defp create_test_api_token(nil), do: :ok

  defp create_test_api_token(user) do
    # 直接创建固定测试 token: test123456
    # 如果已存在，会在插入时失败，但我们可以忽略
    create_fixed_test_token(user, "test123456")
  end

  # 创建固定的测试 token
  defp create_fixed_test_token(user, raw_token) do
    # 计算 token hash
    hash = :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)

    # 创建 token 属性
    expires_at = DateTime.utc_now() |> DateTime.add(180 * 24 * 60 * 60, :second) |> DateTime.truncate(:second)

    # 直接使用 Ecto 写入数据库
    now_sec = DateTime.utc_now() |> DateTime.truncate(:second)
    now_usec = DateTime.utc_now()

    # 使用 raw SQL 插入 - user_id 字段设置为 NULL（已经是 nullable）
    sql = """
    INSERT INTO api_tokens (name, description, expires_at, token_hash, ash_user_id, user_id, created_at, inserted_at, updated_at, is_active)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    RETURNING id
    """

    # user.id 现在已经是字符串
    case AshRepo.query(sql, [
           "Test API Token",
           "Fixed token for testing: #{raw_token}",
           expires_at,
           hash,
           user.id,  # 字符串 ID
           nil,  # user_id 设置为 NULL（不再需要 account_users）
           now_sec,
           now_usec,
           now_usec,
           true
         ]) do
      {:ok, _} ->
        IO.puts("✓ Created fixed test API token: #{raw_token}")
        IO.puts("⚠ Use this token in tests: #{raw_token}")
        save_token_to_file(raw_token)

      {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} ->
        IO.puts("→ Test API token already exists")
      error ->
        IO.puts("✗ Failed to create test API token: #{inspect(error)}")
    end
  end

  # 保存 token 到文件，用于测试
  defp save_token_to_file(token) do
    token_file = Path.join([Application.app_dir(:vmemo, "priv"), "repo", "test_token.txt"])

    case File.write(token_file, token) do
      :ok ->
        IO.puts("✓ Test token saved to: #{token_file}")
      {:error, reason} ->
        IO.puts("⚠ Failed to save token to file: #{reason}")
    end
  end
end

Vmemo.Seeds.TestUsers.run()
