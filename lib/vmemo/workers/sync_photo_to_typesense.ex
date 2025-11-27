defmodule Vmemo.Workers.SyncPhotoToTypesense do
  use Oban.Worker, queue: :sync_typesense, max_attempts: 3

  require Logger
  alias Vmemo.PhotoService.TsPhoto
  alias SmallSdk.Moondream

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"photo_id" => photo_id}}) do
    query =
      "SELECT id::text, note, caption, url, file_id, inserted_at, ash_user_id::text FROM photos WHERE id::text = $1"

    case Vmemo.AshRepo.query(query, [photo_id]) do
      {:ok, %{rows: [row]}} ->
        [id, note, caption, url, file_id, inserted_at, ash_user_id] = row

        photo = %{
          id: id,
          note: note,
          caption: caption,
          url: url,
          file_id: file_id,
          inserted_at: inserted_at,
          ash_user_id: ash_user_id
        }

        sync_to_typesense(photo)

      {:ok, %{rows: []}} ->
        Logger.warning("Photo #{photo_id} not found in database")
        {:discard, :photo_not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  defp sync_to_typesense(photo) do
    inserted_at_unix =
      case photo.inserted_at do
        %NaiveDateTime{} = naive_dt ->
          naive_dt
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.to_unix()

        %DateTime{} = dt ->
          DateTime.to_unix(dt)

        _ ->
          :os.system_time(:second)
      end

    base_data = %{
      id: photo.id,
      note: photo.note || "",
      caption: photo.caption || "",
      note_ids: [],
      url: photo.url,
      file_id: photo.file_id,
      inserted_at: inserted_at_unix,
      inserted_by: photo.ash_user_id
    }

    typesense_data =
      case read_image_as_base64(photo.url) do
        {:ok, image} ->
          Map.put(base_data, :image, image)

        {:error, :file_not_found} ->
          Logger.warning(
            "Photo #{photo.id}: Image file not found at #{photo.url}, syncing without image"
          )

          base_data

        {:error, reason} ->
          Logger.warning(
            "Photo #{photo.id}: Failed to read image (#{inspect(reason)}), syncing without image"
          )

          base_data
      end

    result =
      case TsPhoto.get_photo(photo.id) do
        nil ->
          TsPhoto.create(typesense_data)

        _existing ->
          TsPhoto.update_photo(typesense_data)
      end

    case result do
      {:ok, _} ->
        if is_nil(photo.caption) or photo.caption == "" do
          generate_caption(photo.id, typesense_data[:image])
        end

        :ok

      {:error, reason} ->
        Logger.error("Failed to sync photo #{photo.id} to Typesense: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_caption(photo_id, nil) do
    Logger.info("Photo #{photo_id}: No image data available, skipping caption generation")
    :ok
  end

  defp generate_caption(photo_id, image_base64) do
    case Moondream.caption(image_base64) do
      {:ok, caption} ->
        Logger.info("Photo #{photo_id}: Generated caption: #{String.slice(caption, 0, 50)}...")

        # Only update database, Photo.update's after_action will trigger
        # a new SyncPhotoToTypesense job to sync caption to Typesense
        case Ash.get(Vmemo.Photos.Photo, photo_id, actor: nil) do
          {:ok, photo} ->
            Vmemo.Photos.Photo.update(photo, %{caption: caption}, actor: nil)

          _ ->
            :ok
        end

      {:error, reason} ->
        Logger.warning("Photo #{photo_id}: Failed to generate caption: #{inspect(reason)}")
        :ok
    end
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
