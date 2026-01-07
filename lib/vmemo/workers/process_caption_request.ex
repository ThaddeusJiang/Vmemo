defmodule Vmemo.Workers.ProcessCaptionRequest do
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias Vmemo.Photos.PhotoCaptionRequest
  alias Vmemo.Photos.Photo
  alias Vmemo.PhotoService.TsPhoto

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"request_id" => request_id}}) do
    case Ash.get(PhotoCaptionRequest, request_id, actor: nil) do
      {:ok, request} ->
        process_request(request)

      {:error, %Ash.Error.Query.NotFound{}} ->
        Logger.warning("Caption request #{request_id} not found")
        {:discard, :request_not_found}

      {:error, error} ->
        Logger.error("Failed to get caption request #{request_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp process_request(request) do
    case update_request_status(request, "processing") do
      {:ok, request} ->
        case Ash.get(Photo, request.photo_id, actor: nil) do
          {:ok, photo} ->
            generate_caption(request, photo)

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

  defp generate_caption(request, photo) do
    case TsPhoto.gen_description(photo.id) do
      {:ok, caption} ->
        # Update photo caption
        case Photo.update(photo, %{caption: caption}, actor: nil) do
          {:ok, _updated_photo} ->
            # Update request with success
            update_request_with_success(request, caption)

          {:error, error} ->
            Logger.error("Failed to update photo caption: #{inspect(error)}")
            update_request_with_error(request, "Failed to update photo: #{inspect(error)}")
        end

      {:error, reason} ->
        error_msg = format_error_message(reason)
        update_request_with_error(request, error_msg)
    end
  end

  defp format_error_message(reason) when is_binary(reason), do: reason
  defp format_error_message(reason), do: inspect(reason)

  defp update_request_status(request, status) do
    PhotoCaptionRequest.update(request, %{status: status}, actor: nil)
  end

  defp update_request_with_success(request, caption) do
    case PhotoCaptionRequest.update(
           request,
           %{status: "completed", caption: caption},
           actor: nil
         ) do
      {:ok, updated_request} ->
        broadcast_update(updated_request)
        :ok

      {:error, error} ->
        Logger.error("Failed to update request with success: #{inspect(error)}")
        {:error, error}
    end
  end

  defp update_request_with_error(request, error_message) do
    case PhotoCaptionRequest.update(
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
      "photo_caption_request:#{request.photo_id}",
      {:caption_request_updated,
       %{
         request_id: request.id,
         photo_id: request.photo_id,
         status: request.status,
         caption: request.caption,
         error_message: request.error_message
       }}
    )
  end
end
