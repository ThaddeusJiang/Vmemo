defmodule Vmemo.Workers.SyncNoteToTypesense do
  use Oban.Worker, queue: :sync_typesense, max_attempts: 3

  alias Vmemo.Photos.Note

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"note_id" => note_id}}) do
    case Note.sync_typesense_by_id(note_id, actor: nil, authorize?: false) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :sync_failed}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :note_not_found}
      {:error, error} -> {:error, error}
    end
  end
end
