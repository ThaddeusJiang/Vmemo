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
            raise "Failed to create user: #{inspect(error)}"
        end
    end
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")

    captured_email
    |> Map.get(:body, captured_email)
    |> normalize_email_content()
    |> parse_token_from_email_content()
  end

  defp normalize_email_content(body) when is_map(body) do
    Map.get(body, :text_body) || Map.get(body, :html_body) || inspect(body)
  end

  defp normalize_email_content(body) when is_binary(body), do: body
  defp normalize_email_content(body), do: inspect(body)

  defp parse_token_from_email_content(email_content) do
    if String.contains?(email_content, "[TOKEN]") do
      [_, token | _] = String.split(email_content, "[TOKEN]")
      token
    else
      email_content
      |> extract_token_from_url_path()
      |> jwt_token_or_content(email_content)
    end
  end

  defp extract_token_from_url_path(email_content) do
    case URI.parse(email_content) do
      %{path: path} when is_binary(path) and path != "" ->
        path
        |> String.split("/")
        |> List.last()

      _ ->
        email_content
    end
  end

  defp jwt_token_or_content(token, email_content)
       when is_binary(token) and byte_size(token) > 1 do
    if String.starts_with?(token, "ey"), do: token, else: email_content
  end

  defp jwt_token_or_content(_token, email_content), do: email_content
end
