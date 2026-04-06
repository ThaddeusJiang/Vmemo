defmodule Vmemo.Account.Users do
  @moduledoc false

  require Ash.Query

  alias Vmemo.Account.User

  def list_users do
    Ash.read!(User)
  end

  def get_user!(id), do: Ash.get!(User, id)

  def get_user_by_email(email) do
    case User
         |> Ash.Query.filter(email == ^email)
         |> Ash.read_one() do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  def create_user(attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:register, attrs)
    |> Ash.create()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> Ash.Changeset.for_update(:update_profile, attrs)
    |> Ash.update()
  end

  def delete_user(%User{} = user) do
    Ash.destroy(user)
  end

  def change_user(%User{} = user, attrs \\ %{}) do
    Ash.Changeset.for_update(user, :update_profile, attrs)
  end

  def register_user(attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:register, attrs)
    |> Ash.create()
  end
end
