defmodule Vmemo.Workers.ProcessImportRequest do
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias Vmemo.Admin.ImportRequest
  alias Vmemo.AdminImport

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"request_id" => request_id, "zip_path" => zip_path}}) do
    case Ash.get(ImportRequest, request_id, actor: nil) do
      {:ok, request} ->
        process_request(request, zip_path)

      {:error, %Ash.Error.Query.NotFound{}} ->
        Logger.warning("Import request #{request_id} not found")
        {:discard, :request_not_found}

      {:error, error} ->
        Logger.error("Failed to get import request #{request_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp process_request(request, zip_path) do
    case update_request(request, %{status: "processing"}) do
      {:ok, request} ->
        case AdminImport.import_zip(zip_path) do
          {:ok, result} ->
            update_request_with_success(request, result)

          {:error, %{} = result} ->
            update_request_with_failure(request, "Import completed with errors", result)

          {:error, reason} ->
            update_request_with_failure(request, format_error(reason), %{})
        end

      {:error, error} ->
        Logger.error("Failed to update import request status: #{inspect(error)}")
        {:error, error}
    end
  end

  defp update_request_with_success(request, result) do
    params = %{
      status: "completed",
      metadata: Map.get(result, :metadata),
      result: result,
      error_message: nil
    }

    case update_request(request, params) do
      {:ok, updated_request} ->
        broadcast_update(updated_request)
        :ok

      {:error, error} ->
        Logger.error("Failed to update import request with success: #{inspect(error)}")
        {:error, error}
    end
  end

  defp update_request_with_failure(request, error_message, result) do
    params = %{
      status: "failed",
      metadata: Map.get(result, :metadata),
      result: result,
      error_message: error_message
    }

    case update_request(request, params) do
      {:ok, updated_request} ->
        broadcast_update(updated_request)
        :ok

      {:error, error} ->
        Logger.error("Failed to update import request with failure: #{inspect(error)}")
        {:error, error}
    end
  end

  defp update_request(request, params) do
    ImportRequest.update(request, params, actor: nil)
  end

  defp broadcast_update(request) do
    Phoenix.PubSub.broadcast(
      Vmemo.PubSub,
      "admin_import_request:#{request.id}",
      {:import_request_updated,
       %{
         request_id: request.id,
         status: request.status,
         result: request.result,
         error_message: request.error_message
       }}
    )
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
