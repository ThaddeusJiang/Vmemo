defmodule Vmemo.Photos.Note.Changes.SyncTypesense do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, record, _context ->
      case Vmemo.Photos.Note.sync_typesense_by_id(record.id, actor: nil, authorize?: false) do
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
