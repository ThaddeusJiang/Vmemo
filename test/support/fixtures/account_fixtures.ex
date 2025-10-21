defmodule Vmemo.AccountFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Vmemo.Account` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@vmemo.app"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Vmemo.Account.register_user()

    user
  end
end
