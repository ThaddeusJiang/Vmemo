defmodule VmemoWeb.ApiFixtures do
  @moduledoc """
  Test helper functions: API-related fixtures
  """

  alias Vmemo.Account
  alias Vmemo.Account.ApiToken

  @doc """
  Create and return a test user
  """
  def test_user do
    case Account.get_user_by_email("test@example.com") do
      nil ->
        {:ok, user} =
          Account.register_user(%{
            email: "test@example.com",
            password: "pass123456"
          })

        user

      user ->
        user
    end
  end

  @doc """
  Create a test API token and return the raw token
  """
  def create_test_token(user, attrs \\ %{}) do
    default_attrs = %{
      "name" => "Test API Token",
      "description" => "Automatically generated for testing",
      "expires_at" => "180"
    }

    attrs = Map.merge(default_attrs, attrs)

    case ApiToken.create_for_user(user, attrs) do
      {:ok, _api_token, raw_token} -> raw_token
      {:error, error} -> raise "Failed to create test API token: #{inspect(error)}"
    end
  end
end
