defmodule VmemoWeb.ApiFixtures do
  @moduledoc """
  测试辅助函数：API 相关 fixtures
  """

  alias Vmemo.Account
  alias Vmemo.ApiTokenService

  @doc """
  创建测试用户并返回
  """
  def test_user do
    case Account.get_ash_user_by_email("test@example.com") do
      nil ->
        {:ok, user} =
          Account.register_user(%{
            email: "test@example.com",
            password: "password123456"
          })

        user

      user ->
        user
    end
  end

  @doc """
  创建测试 API token 并返回 raw token
  """
  def create_test_token(user, attrs \\ %{}) do
    default_attrs = %{
      "name" => "Test API Token",
      "description" => "Automatically generated for testing",
      "expires_at" => "180"
    }

    attrs = Map.merge(default_attrs, attrs)

    case ApiTokenService.create_api_token(user, attrs) do
      {:ok, _api_token, raw_token} -> raw_token
      {:error, error} -> raise "Failed to create test API token: #{inspect(error)}"
    end
  end
end
