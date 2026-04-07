defmodule Vmemo.Memo.Changes.SyncTypesense do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    resource = Keyword.fetch!(opts, :resource)

    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      case resource.sync_typesense_by_id(record.id, actor: nil, authorize?: false) do
        {:ok, true} ->
          {:ok, record}

        {:ok, false} ->
          {:error, :sync_failed}

        {:error, %Ash.Error.Query.NotFound{}} ->
          {:ok, record}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end
end
