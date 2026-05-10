defmodule Vmemo.Memo.Changes.SyncTypesense do
  @moduledoc false
  use Ash.Resource.Change
  alias Ash.Resource.Info

  @impl true
  def change(changeset, opts, _context) do
    resource = Keyword.fetch!(opts, :resource)

    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      case resource.sync_typesense_by_id(record.id, actor: nil, authorize?: false) do
        {:ok, true} ->
          update_status_if_supported(resource, record, "completed")

        {:ok, false} ->
          _ = update_status_if_supported(resource, record, "failed")

          {:error, :sync_failed}

        {:error, %Ash.Error.Query.NotFound{}} ->
          {:ok, record}

        {:error, reason} ->
          _ = update_status_if_supported(resource, record, "failed")

          {:error, reason}
      end
    end)
  end

  defp update_status_if_supported(resource, record, status) do
    if supports_status_update?(resource) do
      case Ash.update(record, %{typesense_status: status},
             action: :set_typesense_status,
             actor: nil,
             authorize?: false
           ) do
        {:ok, _updated} -> {:ok, record}
        {:error, reason} -> {:error, reason}
      end
    else
      {:ok, record}
    end
  end

  defp supports_status_update?(resource) do
    match?(
      %{name: :set_typesense_status},
      Info.action(resource, :set_typesense_status)
    )
  end
end
