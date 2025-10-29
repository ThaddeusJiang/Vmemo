defmodule Vmemo.AccountFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Vmemo.Account` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@vmemo.app"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    password = valid_user_password()
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: password,
      password_confirmation: password
    })
  end

  def user_fixture(attrs \\ %{}) do
    # Always generate a completely fresh email to avoid conflicts
    password = valid_user_password()
    fresh_attrs =
      attrs
      |> Map.put_new(:email, unique_user_email())
      |> Map.put_new(:password, password)
      |> Map.put_new(:password_confirmation, password)

    case Vmemo.Account.register_user(fresh_attrs) do
      {:ok, user} ->
        user

      {:error, _error} ->
        # Retry with new unique email if email conflict
        retry_attrs = fresh_attrs |> Map.put(:email, unique_user_email())

        case Vmemo.Account.register_user(retry_attrs) do
          {:ok, user} ->
            user

          {:error, error} ->
            IO.inspect(error, label: "User registration error")
            raise "Failed to create user: #{inspect(error)}"
        end
    end
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    # captured_email is a map with :to and :body keys
    body = Map.get(captured_email, :body, captured_email)
    # If body is a map, try to get text_body or html_body, otherwise use the body
    email_content =
      cond do
        is_map(body) -> Map.get(body, :text_body) || Map.get(body, :html_body) || inspect(body)
        is_binary(body) -> body
        true -> inspect(body)
      end

    # Extract token from URL format
    # For JWT tokens used with ash_authentication, they might be in the URL directly
    if String.contains?(email_content, "[TOKEN]") do
      [_, token | _] = String.split(email_content, "[TOKEN]")
      token
    else
      # If no [TOKEN] markers, try to extract from URL query param or fragment
      # The token might be the last part of the URL
      url_parts = URI.parse(email_content)
      # Extract token from path or query
      token =
        if url_parts.path && String.contains?(url_parts.path, "/") do
          String.split(url_parts.path, "/") |> List.last()
        else
          email_content
        end

      # For JWT tokens, they start with "ey" (base64url encoded)
      if String.starts_with?(token, "ey") do
        token
      else
        # Fallback: try to find JWT-like token in the content
        email_content
      end
    end
  end
end
