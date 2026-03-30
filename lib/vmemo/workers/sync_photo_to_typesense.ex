defmodule Vmemo.Workers.SyncPhotoToTypesense do
  use Oban.Worker, queue: :sync_typesense, max_attempts: 3

  require Logger
  alias Vmemo.Photos.Photo
  alias SmallSdk.Moondream

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"photo_id" => photo_id}}) do
    with {:ok, photo} <- Ash.get(Photo, photo_id, actor: nil, authorize?: false),
         {:ok, true} <- Photo.sync_typesense_by_id(photo_id, actor: nil, authorize?: false) do
      maybe_generate_caption(photo)
    else
      {:error, %Ash.Error.Query.NotFound{}} ->
        Logger.warning("Photo #{photo_id} not found in database")
        {:discard, :photo_not_found}

      {:ok, false} ->
        {:error, :sync_failed}

      {:error, error} ->
        {:error, error}
    end
  end

  defp maybe_generate_caption(photo) do
    if is_nil(photo.caption) or photo.caption == "" do
      generate_caption(photo)
    else
      :ok
    end
  end

  defp generate_caption(photo) do
    with {:ok, image_base64} <- read_image_as_base64(photo.url),
         {:ok, caption} <- Moondream.caption(image_base64) do
      Logger.info("Photo #{photo.id}: Generated caption: #{String.slice(caption, 0, 50)}...")

      case Photo.update(photo, %{caption: caption}, actor: nil, authorize?: false) do
        {:ok, _updated_photo} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :file_not_found} ->
        Logger.info("Photo #{photo.id}: No image data available, skipping caption generation")
        :ok

      {:error, reason} ->
        Logger.warning("Photo #{photo.id}: Failed to generate caption: #{inspect(reason)}")
        :ok
    end
  end

  defp read_image_as_base64(url) do
    relative_path =
      url
      |> String.trim_leading("/")
      |> String.trim_leading("storage/v1/")

    file_path = Path.join(["storage", "v1", relative_path])

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
