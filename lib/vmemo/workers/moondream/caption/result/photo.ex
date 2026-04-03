defmodule Vmemo.Workers.Moondream.Caption.Result.Photo do
  require Logger

  alias Vmemo.Photos.Photo

  def on_success(%{photo: photo}, caption) do
    case Photo.update(photo, %{caption: caption}, actor: nil, authorize?: false) do
      {:ok, _updated_photo} ->
        Logger.info("Photo #{photo.id}: Generated caption: #{String.slice(caption, 0, 50)}...")
        :ok

      {:error, reason} ->
        Logger.warning("Photo #{photo.id}: Failed to persist caption: #{inspect(reason)}")
        :ok
    end
  end

  def on_error(%{photo_id: photo_id}, %Ash.Error.Query.NotFound{}) do
    Logger.warning("Photo #{photo_id} not found in database")
    {:discard, :photo_not_found}
  end

  def on_error(%{photo: photo}, :file_not_found) do
    Logger.info("Photo #{photo.id}: No image data available, skipping caption generation")
    :ok
  end

  def on_error(%{photo_id: photo_id}, :file_not_found) do
    Logger.info("Photo #{photo_id}: No image data available, skipping caption generation")
    :ok
  end

  def on_error(%{photo: photo}, reason) do
    Logger.warning("Photo #{photo.id}: Failed to generate caption: #{inspect(reason)}")
    :ok
  end

  def on_error(%{photo_id: photo_id}, reason) do
    Logger.warning("Photo #{photo_id}: Failed to generate caption: #{inspect(reason)}")
    :ok
  end

  def on_error(_context, reason) do
    Logger.warning("Photo caption job failed: #{inspect(reason)}")
    :ok
  end

  def on_skip(_context, _reason), do: :ok
end
