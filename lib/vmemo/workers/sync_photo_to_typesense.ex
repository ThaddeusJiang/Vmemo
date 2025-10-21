defmodule Vmemo.Workers.SyncPhotoToTypesense do
  use Oban.Worker, queue: :sync_typesense, max_attempts: 3

  alias Vmemo.Photos.Photo
  alias Vmemo.PhotoService.TsPhoto

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"photo_id" => photo_id}}) do
    case Ash.get(Photo, photo_id) do
      {:ok, photo} ->
        sync_to_typesense(photo)

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, :photo_not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  defp sync_to_typesense(photo) do
    typesense_data = %{
      id: photo.id,
      image: photo.image,
      note: photo.note,
      url: photo.url,
      file_id: photo.file_id,
      inserted_at: DateTime.to_unix(photo.inserted_at),
      inserted_by: photo.user_id
    }

    case TsPhoto.get_photo(photo.id) do
      nil ->
        TsPhoto.create(typesense_data)

      _existing ->
        TsPhoto.update_photo(typesense_data)
    end
  end
end
