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
        email: "admin@mail.com",
        password: "password123456",
        display_name: "Admin User"
      },
      %{
        email: "dev@mail.com",
        password: "password123456",
        display_name: "Dev User"
      },
      %{
        email: "test@mail.com",
        password: "password123456",
        display_name: "Test User"
      }
    ]

    Enum.each(test_users, fn user_attrs ->
      case Account.get_user_by_email(user_attrs.email) do
        nil ->
          case Account.register_user(user_attrs) do
            {:ok, user} ->
              # Confirm the user and set display_name automatically for dev/test
              user
              |> Ecto.Changeset.change(%{
                confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second),
                display_name: user_attrs.display_name
              })
              |> Repo.update!()

              IO.puts("✓ Created and confirmed user: #{user_attrs.email} (#{user_attrs.display_name})")

            {:error, changeset} ->
              IO.puts("✗ Failed to create user #{user_attrs.email}: #{inspect(changeset.errors)}")
          end

        existing_user ->
          # Update display_name for existing users if it's not set
          if is_nil(existing_user.display_name) do
            existing_user
            |> Ecto.Changeset.change(%{display_name: user_attrs.display_name})
            |> Repo.update!()

            IO.puts("✓ Updated display_name for existing user: #{user_attrs.email} (#{user_attrs.display_name})")
          else
            IO.puts("→ User already exists: #{user_attrs.email}")
          end
      end
    end)
  end
end

Vmemo.Seeds.TestUsers.run()
