defmodule Vmemo.Memo.Changes.SyncTypesense do
  @moduledoc false
  use Ash.Resource.Change
  require Ash.Query
  alias Ash.Resource.Info
  alias Vmemo.Jobs.Job
  require Logger

  @impl true
  def change(changeset, opts, _context) do
    resource = Keyword.fetch!(opts, :resource)

    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      resource
      |> sync_typesense(record)
      |> handle_sync_result(resource, record)
    end)
  end

  defp sync_typesense(resource, record) do
    resource.sync_typesense_by_id(record.id, actor: nil, authorize?: false)
  end

  defp handle_sync_result({:ok, true}, resource, record) do
    with {:ok, _} <- update_status_if_supported(resource, record, "completed") do
      sync_typesense_job_completed(record)
      {:ok, record}
    end
  end

  defp handle_sync_result({:ok, false}, _resource, record) do
    Logger.warning("typesense sync retrying: sync_failed",
      image_id: record.id,
      user_id: record.user_id
    )

    {:error, :sync_failed}
  end

  defp handle_sync_result({:error, %Ash.Error.Query.NotFound{}}, _resource, record) do
    {:ok, record}
  end

  defp handle_sync_result({:error, reason}, _resource, record) do
    Logger.warning("typesense sync retrying: #{inspect(reason)}",
      image_id: record.id,
      user_id: record.user_id
    )

    {:error, reason}
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

  defp sync_typesense_job_completed(record) do
    query =
      Job
      |> Ash.Query.filter(image_id: record.id, kind: "typesense")
      |> Ash.Query.limit(1)

    case Ash.read(query, actor: nil, authorize?: false) do
      {:ok, [job | _]} ->
        _ = Ash.update(job, %{}, action: :mark_completed, actor: nil, authorize?: false)
        :ok

      _ ->
        _ =
          Ash.create(
            Job,
            %{
              image_id: record.id,
              user_id: record.user_id,
              kind: "typesense",
              status: "completed",
              worker: "Vmemo.Memo.Image.Workers.SyncTypesense"
            },
            action: :create_requested,
            actor: nil,
            authorize?: false
          )

        :ok
    end
  rescue
    _ -> :ok
  end
end
