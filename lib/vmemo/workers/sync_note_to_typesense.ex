defmodule Vmemo.Workers.SyncNoteToTypesense do
  use Oban.Worker, queue: :sync_typesense, max_attempts: 3

  alias Vmemo.Photos.Note
  alias Vmemo.PhotoService.TsNote
  alias Vmemo.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"note_id" => note_id}}) do
    case Repo.get(Note, note_id) do
      nil ->
        {:error, :note_not_found}

      note ->
        sync_to_typesense(note)
    end
  end

  defp sync_to_typesense(note) do
    note_with_photos = Repo.preload(note, :photos)

    photo_ids =
      note_with_photos.photos
      |> Enum.map(& &1.id)

    typesense_data = %{
      id: note.id,
      text: note.text,
      belongs_to: note.user_id,
      photo_ids: photo_ids,
      inserted_at: DateTime.to_unix(note.inserted_at),
      updated_at: DateTime.to_unix(note.updated_at)
    }

    case TsNote.get(note.id) do
      nil ->
        TsNote.create(typesense_data)

      _existing ->
        TsNote.update(typesense_data)
    end
  end
end
