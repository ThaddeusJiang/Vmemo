defmodule Vmemo.Photos.Photo.Changes.SyncTypesense do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      case Vmemo.Photos.Photo.sync_typesense_by_id(record.id, actor: nil, authorize?: false) do
        {:ok, true} ->
          {:ok, record}

        {:ok, false} ->
          {:error, :sync_failed}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end
end
