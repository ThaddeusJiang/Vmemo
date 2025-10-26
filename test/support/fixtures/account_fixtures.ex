defmodule Vmemo.AccountFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Vmemo.Account` context.
  """

  def unique_user_email, do: "user#{System.unique_integer([:positive])}@vmemo.app"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    # Ensure email and password are always provided
    attrs = valid_user_attributes(attrs)

    {:ok, user} = Vmemo.Account.register_user(attrs)

    user
  end

  @doc """
  Generate a confirmed user.
  """
  def confirmed_user_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)

    # Set confirmed_at to mark user as confirmed
    {:ok, confirmed_user} =
      Vmemo.Account.update_ash_user(user, %{confirmed_at: DateTime.utc_now()})

    confirmed_user
  end

  @doc """
  Generate a session token for the given user.
  """
  def user_session_token_fixture(user) do
    Vmemo.Account.generate_user_session_token(user)
  end

  @doc """
  Extract user token from email body
  """
  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    # Handle both :text_body (old) and :body (new) formats
    body = Map.get(captured_email, :text_body) || Map.get(captured_email, :body, "")
    [_, token | _] = String.split(body, "[TOKEN]")
    token
  end
end
