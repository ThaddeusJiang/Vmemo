defmodule Vmemo.ApiTokenService do
  @moduledoc """
  API Token 服务模块，使用 AshRepo 处理 API Token 相关功能
  """

  require Logger
  alias Vmemo.Account.ApiToken

  ## API Token functions

  @doc """
  Lists all API tokens for a user.
  """
  def list_user_api_tokens(user) do
    case ApiToken.list_by_user(user.id, actor: user) do
      {:ok, tokens} -> tokens
      {:error, _} -> []
    end
  end

  @doc """
  Gets a single API token.
  """
  def get_api_token!(id) do
    case ApiToken.get_by_id(id) do
      {:ok, token} -> token
      {:error, _} -> raise "No API token found with id: #{id}"
    end
  end

  @doc """
  Gets a single API token by user and id.
  """
  def get_user_api_token!(user, id) do
    case ApiToken.get_by_user_and_id(id, user.id, actor: user) do
      {:ok, token} -> token
      {:error, _} -> raise "No API token found with id: #{id} for user: #{user.id}"
    end
  end

  @doc """
  Creates an API token.
  """
  def create_api_token(user, attrs) do
    expires_at = attrs |> Map.get("expires_at") |> parse_expires_at()

    attrs_atoms =
      attrs
      |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
      |> Map.new()

    attrs_with_expires = Map.put(attrs_atoms, :expires_at, expires_at)
    attrs_with_user = Map.put(attrs_with_expires, :user_id, user.id)

    {raw_token, hash} = Vmemo.Account.ApiToken.generate_token()
    attrs_with_hash = Map.put(attrs_with_user, :token_hash, hash)

    case ApiToken.create(attrs_with_hash, actor: user) do
      {:ok, api_token} ->
        log_token_usage(api_token, "create", nil, %{})
        {:ok, api_token, raw_token}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp parse_expires_at("30"), do: expires_in_days(30)
  defp parse_expires_at("90"), do: expires_in_days(90)
  defp parse_expires_at("180"), do: expires_in_days(180)
  defp parse_expires_at("never"), do: nil
  defp parse_expires_at(nil), do: expires_in_days(90)

  defp parse_expires_at(date) when is_binary(date) do
    case DateTime.from_iso8601(date <> ":00") do
      {:ok, datetime, _} -> DateTime.truncate(datetime, :second)
      {:error, _} -> expires_in_days(90)
    end
  end

  defp parse_expires_at(%DateTime{} = date), do: DateTime.truncate(date, :second)
  defp parse_expires_at(_), do: expires_in_days(90)

  defp expires_in_days(days) do
    DateTime.utc_now()
    |> DateTime.add(days * 24 * 60 * 60, :second)
    |> DateTime.truncate(:second)
  end

  @doc """
  Updates an API token.
  """
  def update_api_token(api_token, attrs) do
    case ApiToken.update(api_token, attrs, actor: api_token) do
      {:ok, api_token} ->
        {:ok, api_token}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes an API token.
  """
  def delete_api_token(api_token) do
    # 记录删除日志
    log_token_usage(api_token, "revoked", nil, %{})

    case ApiToken.destroy(api_token, actor: api_token) do
      :ok -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Toggles the active status of an API token.
  """
  def toggle_api_token_status(api_token) do
    case Ash.ActionInput.for_action(ApiToken, :toggle_status, %{id: api_token.id},
           actor: api_token
         )
         |> Ash.update() do
      {:ok, updated_token} ->
        # 记录状态变更日志
        action = if updated_token.is_active, do: "activated", else: "deactivated"
        log_token_usage(updated_token, action, nil, %{})
        {:ok, updated_token}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Verifies an API token and returns the associated user.
  """
  def verify_api_token(token) do
    case ApiToken.verify_token(token) do
      {:ok, api_token} ->
        # 检查是否过期（nil 表示永不过期）
        if api_token.expires_at &&
             DateTime.compare(DateTime.utc_now(), api_token.expires_at) == :gt do
          {:error, "Token expired"}
        else
          # 更新最后使用时间和使用计数
          update_token_usage(api_token)
          # load user
          api_token = Ash.load!(api_token, :user)
          {:ok, api_token}
        end

      {:error, _} ->
        {:error, "Invalid token"}
    end
  end

  @doc """
  Gets tokens that are expiring soon (within 7 days).
  """
  def get_expiring_tokens(user_id, days \\ 7) do
    case ApiToken.get_expiring_tokens(user_id, days, actor: %{id: user_id}) do
      {:ok, tokens} -> tokens
      {:error, _} -> []
    end
  end

  @doc """
  Gets expired tokens.
  """
  def get_expired_tokens(user_id) do
    case ApiToken.get_expired_tokens(user_id, actor: %{id: user_id}) do
      {:ok, tokens} -> tokens
      {:error, _} -> []
    end
  end

  @doc """
  Gets tokens that were used today.
  """
  def get_today_used_tokens(user_id) do
    case ApiToken.get_today_used_tokens(user_id, actor: %{id: user_id}) do
      {:ok, tokens} -> tokens
      {:error, _} -> []
    end
  end

  @doc """
  Counts total usage count for tokens that were used today.
  Since usage_count is cumulative, we sum the usage_count of all tokens
  that were used today as an approximation.
  """
  def count_today_usage(user_id) do
    get_today_used_tokens(user_id)
    |> Enum.map(&(&1.usage_count || 0))
    |> Enum.sum()
  end

  # Private functions

  defp update_token_usage(api_token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    current_count = api_token.usage_count || 0

    case ApiToken.update(
           api_token,
           %{
             last_used_at: now,
             usage_count: current_count + 1
           },
           actor: api_token
         ) do
      {:ok, _updated_token} ->
        :ok

      {:error, changeset} ->
        Logger.error(
          "Failed to update token usage for token #{api_token.id}: #{inspect(changeset.errors)}"
        )

        :error
    end
  end

  defp log_token_usage(api_token, action, _conn, metadata) do
    Logger.info(
      "API Token #{action}: token_id=#{api_token.id}, user_id=#{api_token.user_id}, metadata=#{inspect(metadata)}"
    )
  end
end
