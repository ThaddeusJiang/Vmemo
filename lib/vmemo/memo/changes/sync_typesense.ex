defmodule Vmemo.Memo.Changes.SyncTypesense do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    resource = Keyword.fetch!(opts, :resource)

    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      case resource.sync_typesense_by_id(record.id, actor: nil, authorize?: false) do
        {:ok, true} ->
          case Ash.update(record, %{typesense_status: "completed"},
                 action: :set_typesense_status,
                 actor: nil,
                 authorize?: false
               ) do
            {:ok, _updated} -> {:ok, record}
            {:error, reason} -> {:error, reason}
          end

        {:ok, false} ->
          _ =
            Ash.update(record, %{typesense_status: "failed"},
              action: :set_typesense_status,
              actor: nil,
              authorize?: false
            )

          {:error, :sync_failed}

        {:error, %Ash.Error.Query.NotFound{}} ->
          {:ok, record}

        {:error, reason} ->
          _ =
            Ash.update(record, %{typesense_status: "failed"},
              action: :set_typesense_status,
              actor: nil,
              authorize?: false
            )

          {:error, reason}
      end
    end)
  end
end
