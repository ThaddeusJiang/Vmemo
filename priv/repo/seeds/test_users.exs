defmodule Vmemo.Seeds.TestUsers do
  @moduledoc """
  Creates test users for development and testing environments.
  """

  alias Vmemo.Account
  alias Vmemo.AshRepo
  alias Vmemo.Repo

  require Ecto.Query

  def run do
    # 创建 test 用户
    user = create_test_user()

    # 为 test 用户创建 API token
    create_test_api_token(user)
  end

  defp create_test_user do
    email = "test@mail.com"
    password = "password123456"

    # 确保有 account_users 记录（用于 api_tokens.user_id 外键）
    create_account_user_if_needed(email)

    case Account.get_ash_user_by_email(email) do
      nil ->
        case Account.register_user(%{email: email, password: password}) do
          {:ok, user} ->
            # 确认用户
            user
            |> Ash.Changeset.for_update(:update_profile, %{
              confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
            })
            |> Ash.update!()

            IO.puts("✓ Created and confirmed user: #{email}")
            user

          {:error, changeset} ->
            IO.puts("✗ Failed to create user #{email}: #{inspect(changeset.errors)}")
            nil
        end

      existing_user ->
        IO.puts("→ User already exists: #{email}")
        existing_user
    end
  end

  # 创建 account_users 记录（用于兼容旧系统）
  defp create_account_user_if_needed(email) do
    # 检查是否已存在
    sql = "SELECT id FROM account_users WHERE email = $1 LIMIT 1"

    case Repo.query(sql, [email]) do
      {:ok, %{rows: []}} ->
        # 需要创建
        insert_sql = """
        INSERT INTO account_users (email, hashed_password, inserted_at, updated_at)
        VALUES ($1, $2, NOW(), NOW())
        RETURNING id
        """

        # 生成一个简单的 hash
        hash = Bcrypt.hash_pwd_salt("dummy")

        case Repo.query(insert_sql, [email, hash]) do
          {:ok, %{rows: [[id]]}} ->
            IO.puts("✓ Created account_users record: #{id}")
          _ ->
            :ok
        end
      _ ->
        :ok
    end
  end

  # 获取 account_users 的 id
  defp get_account_user_id do
    sql = "SELECT id FROM account_users LIMIT 1"

    case Repo.query(sql, []) do
      {:ok, %{rows: [[id]]}} -> id
      _ -> 1  # fallback
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

    # 使用 raw SQL 插入以绕过 Ash/Ecto 限制
    # 尝试不设置 user_id 或者设置一个存在的值
    # 获取一个 account_users 的 id
    account_user_id = get_account_user_id()

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
           account_user_id,  # 整数 ID from account_users
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
