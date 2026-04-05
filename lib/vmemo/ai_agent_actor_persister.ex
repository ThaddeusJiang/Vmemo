defmodule Vmemo.AiAgentActorPersister do
  use AshOban.ActorPersister
  alias Vmemo.Repo.RLS

  def store(%Vmemo.Account.User{id: id}), do: %{"type" => "user", "id" => id}

  def lookup(%{"type" => "user", "id" => id}) do
    RLS.with_bypass(fn ->
      with {:ok, user} <- Ash.get(Vmemo.Account.User, id, authorize?: false) do
        {:ok, Ash.Resource.set_metadata(user, %{chat_agent?: true})}
      end
    end)
  end

  def lookup(nil), do: {:ok, nil}
end
