defmodule Vmemo.Workers.Moondream.Caption.Result.Request do
  require Logger

  alias Vmemo.Photos.Photo
  alias Vmemo.Photos.PhotoCaptionRequest

  def on_success(%{request: request, photo: photo}, caption) do
    case Photo.update(photo, %{caption: caption}, actor: nil) do
      {:ok, _updated_photo} ->
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

      {:error, error} ->
        on_error(%{request: request, photo: photo}, {:photo_update_failed, error})
    end
  end

  def on_error(%{request: request}, reason) do
    error_message = format_error_message(reason)

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

  def on_error(%{request_id: request_id}, %Ash.Error.Query.NotFound{}) do
    Logger.warning("Caption request #{request_id} not found")
    {:discard, :request_not_found}
  end

  def on_error(%{request_id: request_id}, reason) do
    Logger.error(
      "Caption request #{request_id} failed before loading context: #{inspect(reason)}"
    )

    :ok
  end

  def on_error(_context, reason) do
    Logger.error("Caption request failed: #{inspect(reason)}")
    :ok
  end

  def on_skip(_context, _reason), do: :ok

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

  defp format_error_message({:photo_update_failed, reason}) do
    "Failed to update photo: #{inspect(reason)}"
  end

  defp format_error_message(reason) when is_binary(reason), do: reason
  defp format_error_message(reason), do: inspect(reason)
end
