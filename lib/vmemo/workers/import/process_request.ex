defmodule Vmemo.Workers.Import.ProcessRequest do
  use Oban.Worker, queue: :import_requests, max_attempts: 3

  require Logger

  alias Vmemo.Admin.ImportRequest
  alias Vmemo.AdminImport

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}), do: execute(args)

  def execute(%{"request_id" => request_id}) do
    case Ash.get(ImportRequest, request_id, actor: nil) do
      {:ok, request} ->
        process_request(request)

      {:error, %Ash.Error.Query.NotFound{}} ->
        Logger.warning("Import request #{request_id} not found")
        {:discard, :request_not_found}

      {:error, error} ->
        Logger.error("Failed to get import request #{request_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  def execute(_args), do: {:error, :invalid_import_request_args}

  defp process_request(request) do
    case request.import_zip_path do
      path when is_binary(path) and path != "" ->
        run_import(request, path)

      _ ->
        update_request_with_failure(request, "Import ZIP path is missing", %{})
    end
  end

  defp run_import(request, zip_path) do
    case update_request(request, %{
           status: "processing",
           metadata: progress_metadata("Starting", 0)
         }) do
      {:ok, request} ->
        case AdminImport.import_zip(zip_path, &update_request_progress(request, &1)) do
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
      metadata: result_metadata(result, "Completed", 100),
      result: result,
      error_message: nil,
      import_zip_path: nil
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
      metadata: result_metadata(result, "Failed", 100),
      result: result,
      error_message: error_message,
      import_zip_path: nil
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

  defp update_request_progress(request, progress) do
    metadata =
      request.metadata
      |> ensure_map()
      |> Map.put("progress", progress)

    case update_request(request, %{metadata: metadata}) do
      {:ok, updated_request} ->
        broadcast_update(updated_request)
        :ok

      {:error, error} ->
        Logger.error("Failed to update import request progress: #{inspect(error)}")
        :error
    end
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
         error_message: request.error_message,
         metadata: request.metadata
       }}
    )
  end

  defp progress_metadata(stage, percent) do
    %{"progress" => %{stage: stage, percent: percent}}
  end

  defp result_metadata(result, stage, percent) do
    meta = Map.get(result, :metadata, %{}) |> ensure_map()
    Map.put(meta, "progress", %{stage: stage, percent: percent})
  end

  defp ensure_map(nil), do: %{}
  defp ensure_map(meta) when is_map(meta), do: meta
  defp ensure_map(_meta), do: %{}

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
