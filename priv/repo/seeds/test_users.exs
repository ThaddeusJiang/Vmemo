defmodule Vmemo.Seeds.TestUsers do
  @moduledoc """
  Creates test users for development and testing environments.
  """

  alias Vmemo.Account
  alias Vmemo.Repo

  def run do
    create_test_users()
  end

  defp create_test_users do
    test_users = [
      %{
        email: "test@example.com",
        password: "password123456",
        display_name: "Test User"
      },
      %{
        email: "dev@example.com",
        password: "password123456",
        display_name: "Dev User"
      }
    ]

    Enum.each(test_users, fn user_attrs ->
      case Account.get_user_by_email(user_attrs.email) do
        nil ->
          case Account.register_user(user_attrs) do
            {:ok, user} ->
              # Confirm the user automatically for dev/test
              user
              |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
              |> Repo.update!()

              IO.puts("✓ Created and confirmed user: #{user_attrs.email}")

            {:error, changeset} ->
              IO.puts("✗ Failed to create user #{user_attrs.email}: #{inspect(changeset.errors)}")
          end

        _user ->
          IO.puts("→ User already exists: #{user_attrs.email}")
      end
    end)
  end
end

Vmemo.Seeds.TestUsers.run()
