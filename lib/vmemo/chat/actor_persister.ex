defmodule Vmemo.Chat.ActorPersister do
  @moduledoc false
  use AshOban.ActorPersister

  def store(%Vmemo.Account.User{id: id}), do: %{"type" => "user", "id" => id}

  def lookup(%{"type" => "user", "id" => id}) do
    with {:ok, user} <- Ash.get(Vmemo.Account.User, id, authorize?: false) do
      # you can change the behavior of actions
      # or what your policies allow
      # using the `chat_agent?` metadata
      {:ok, Ash.Resource.set_metadata(user, %{chat_agent?: true})}
    end
  end

  # This allows you to set a default actor
  # in cases where no actor was present
  # when scheduling.
  def lookup(nil), do: {:ok, nil}
end
