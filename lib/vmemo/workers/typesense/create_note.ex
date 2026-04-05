defmodule Vmemo.Workers.Typesense.CreateNote do
  use Oban.Worker, queue: :sync_typesense, max_attempts: 3

  alias Vmemo.Photos.Note
  alias Vmemo.Repo.RLS

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"note_id" => note_id}}) do
    RLS.with_bypass(fn ->
      case Note.sync_typesense_by_id(note_id, actor: nil, authorize?: false) do
        {:ok, true} -> :ok
        {:ok, false} -> {:error, :sync_failed}
        {:error, %Ash.Error.Query.NotFound{}} -> {:error, :note_not_found}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
