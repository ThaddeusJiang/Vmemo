defmodule VmemoWeb.ApiFixtures do
  @moduledoc """
  Fixtures for API testing
  """

  alias Vmemo.Account
  alias Vmemo.ApiTokenService

  @test_email "test@mail.com"
  @test_password "password123456"

  @doc """
  Gets or creates the test user.
  """
  def test_user do
    case Account.get_ash_user_by_email(@test_email) do
      nil ->
        # Create test user if not exists
        {:ok, user} = Account.register_user(%{
          email: @test_email,
          password: @test_password
        })
        user
      user ->
        user
    end
  end

  @doc """
  Gets the test API token. If token doesn't exist, creates one.
  Returns the raw token string.
  """
  def test_api_token do
    user = test_user()

    # Try to find existing test token
    case ApiTokenService.list_user_api_tokens(user) do
      [] ->
        # Create new token if doesn't exist
        attrs = %{
          "name" => "Test API Token",
          "description" => "Automatically generated for testing",
          "expires_at" => "180"
        }

        case ApiTokenService.create_api_token(user, attrs) do
          {:ok, _api_token, raw_token} -> raw_token
          _ -> raise "Failed to create test API token"
        end

      [token | _] ->
        # Use existing token hash to verify
        # For testing, we'll create a new token to get the raw token
        create_new_test_token(user)
    end
  end

  # Helper to create a new token and return raw token
  defp create_new_test_token(user) do
    attrs = %{
      "name" => "Test API Token - New",
      "description" => "New test token",
      "expires_at" => "180"
    }

    case ApiTokenService.create_api_token(user, attrs) do
      {:ok, _api_token, raw_token} -> raw_token
      _ -> raise "Failed to create new test token"
    end
  end

  @doc """
  Reads test token from file if available
  """
  def test_token_from_file do
    token_file = Path.join([
      Application.app_dir(:vmemo, "priv"),
      "repo",
      "test_token.txt"
    ])

    case File.read(token_file) do
      {:ok, token} -> String.trim(token)
      {:error, _} -> test_api_token()
    end
  end

  @doc """
  Creates an authorization header with the test token
  """
  def test_auth_header, do: {"authorization", "Bearer #{test_token_from_file()}"}

  @doc """
  Reads test token from file
  """
  def read_test_token_from_file do
    token_file = Path.join([Application.app_dir(:vmemo, "priv"), "repo", "test_token.txt"])

    case File.read(token_file) do
      {:ok, token} -> String.trim(token)
      {:error, _} ->
        IO.puts("⚠ Test token file not found, creating new token...")
        test_token_from_db()
    end
  end

  defp test_token_from_db do
    user = test_user()

    # Query for the test token
    sql = "SELECT token_hash FROM api_tokens WHERE name = $1 AND ash_user_id = $2 LIMIT 1"

    case Vmemo.AshRepo.query(sql, ["Test API Token", user.id]) do
      {:ok, %{rows: [[token_hash]]}} ->
        # We can't get the raw token from hash, so return the hash
        token_hash
      _ ->
        "test123456"  # fallback
    end
  end
end
