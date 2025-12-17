defmodule Vmemo.Workers.ProcessMoondreamRequest do
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias Vmemo.Photos.PhotoMoondreamRequest
  alias Vmemo.Photos.Photo
  alias SmallSdk.Moondream

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"request_id" => request_id}}) do
    case Ash.get(PhotoMoondreamRequest, request_id, actor: nil) do
      {:ok, request} ->
        process_request(request)

      {:error, %Ash.Error.Query.NotFound{}} ->
        Logger.warning("Moondream request #{request_id} not found")
        {:discard, :request_not_found}

      {:error, error} ->
        Logger.error("Failed to get moondream request #{request_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp process_request(request) do
    case update_request_status(request, "processing") do
      {:ok, request} ->
        case Ash.get(Photo, request.photo_id, actor: nil) do
          {:ok, photo} ->
            case read_image_as_base64(photo.url) do
              {:ok, image_base64} ->
                call_moondream_api(request, image_base64)

              {:error, reason} ->
                Logger.error("Failed to read image for photo #{photo.id}: #{inspect(reason)}")

                update_request_with_error(request, "Failed to read image: #{inspect(reason)}")
            end

          {:error, %Ash.Error.Query.NotFound{}} ->
            Logger.warning("Photo #{request.photo_id} not found")
            update_request_with_error(request, "Photo not found")

          {:error, error} ->
            Logger.error("Failed to get photo #{request.photo_id}: #{inspect(error)}")
            update_request_with_error(request, "Failed to get photo: #{inspect(error)}")
        end

      {:error, error} ->
        Logger.error("Failed to update request status to processing: #{inspect(error)}")
        {:error, error}
    end
  end

  defp call_moondream_api(request, image_base64) do
    function_type =
      case request.function_type do
        "query" -> :query
        "caption" -> :caption
        "point" -> :point
        "detect" -> :detect
        "segment" -> :segment
        _ -> {:error, "Invalid function type: #{request.function_type}"}
      end

    result =
      case function_type do
        {:error, _} = error ->
          error

        :caption ->
          Moondream.caption(image_base64)

        :query ->
          if is_nil(request.prompt) or request.prompt == "" do
            {:error, "Prompt is required for query"}
          else
            Moondream.query(image_base64, request.prompt)
          end

        :point ->
          if is_nil(request.prompt) or request.prompt == "" do
            {:error, "Prompt is required for point"}
          else
            Moondream.point(image_base64, request.prompt)
          end

        :detect ->
          if is_nil(request.prompt) or request.prompt == "" do
            {:error, "Prompt is required for detect"}
          else
            Moondream.detect(image_base64, request.prompt)
          end

        :segment ->
          if is_nil(request.prompt) or request.prompt == "" do
            {:error, "Prompt is required for segment"}
          else
            Moondream.segment(image_base64, request.prompt)
          end
      end

    case result do
      {:ok, api_result} ->
        update_request_with_result(request, api_result)

      {:error, reason} ->
        error_msg = format_error_message(reason)
        update_request_with_error(request, error_msg)
    end
  end

  defp format_error_message(reason) when is_binary(reason), do: reason
  defp format_error_message(reason), do: inspect(reason)

  defp update_request_status(request, status) do
    PhotoMoondreamRequest.update(request, %{status: status}, actor: nil)
  end

  defp update_request_with_result(request, result) do
    result_map =
      case result do
        map when is_map(map) -> map
        list when is_list(list) -> %{data: list}
        value when is_binary(value) -> %{text: value}
        other -> %{result: other}
      end

    case PhotoMoondreamRequest.update(
           request,
           %{status: "completed", result: result_map},
           actor: nil
         ) do
      {:ok, updated_request} ->
        broadcast_update(updated_request)
        :ok

      {:error, error} ->
        Logger.error("Failed to update request with result: #{inspect(error)}")
        {:error, error}
    end
  end

  defp update_request_with_error(request, error_message) do
    case PhotoMoondreamRequest.update(
           request,
           %{status: "failed", error_message: error_message},
           actor: nil
         ) do
      {:ok, updated_request} ->
        broadcast_update(updated_request)
        :ok

      {:error, error} ->
        Logger.error("Failed to update request with error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp broadcast_update(request) do
    Phoenix.PubSub.broadcast(
      Vmemo.PubSub,
      "photo_moondream_request:#{request.photo_id}",
      {:moondream_request_updated,
       %{
         request_id: request.id,
         photo_id: request.photo_id,
         status: request.status,
         result: request.result,
         error_message: request.error_message
       }}
    )
  end

  defp read_image_as_base64(url) do
    relative_path =
      url
      |> String.trim_leading("/")
      |> String.trim_leading("storage/v1/")

    file_path =
      if Mix.env() == :prod do
        Path.join([Application.app_dir(:vmemo, "priv"), "storage", "v1", relative_path])
      else
        Path.join(["storage", "v1", relative_path])
      end

    case File.read(file_path) do
      {:ok, binary} ->
        {:ok, Base.encode64(binary)}

      {:error, :enoent} ->
        {:error, :file_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
