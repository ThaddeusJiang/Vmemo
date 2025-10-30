defmodule Vmemo.Workers.SyncPhotoToTypesense do
  use Oban.Worker, queue: :sync_typesense, max_attempts: 3

  alias Vmemo.PhotoService.TsPhoto

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"photo_id" => photo_id}}) do
    # 使用字符串查询避免 UUID 转换问题
    query =
      "SELECT id::text, note, url, file_id, inserted_at, user_id FROM photos WHERE id::text = $1"

    case Vmemo.AshRepo.query(query, [photo_id]) do
      {:ok, %{rows: [row]}} ->
        [id, note, url, file_id, inserted_at, user_id] = row

        photo = %{
          id: id,
          note: note,
          url: url,
          file_id: file_id,
          inserted_at: inserted_at,
          user_id: user_id
        }

        sync_to_typesense(photo)

      {:ok, %{rows: []}} ->
        {:error, :photo_not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  defp sync_to_typesense(photo) do
    # 将 NaiveDateTime 转换为 DateTime 然后转换为 unix 时间戳
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

    typesense_data = %{
      id: photo.id,
      image: photo.url,
      note: photo.note,
      note_ids: [],
      url: photo.url,
      file_id: photo.file_id,
      inserted_at: inserted_at_unix,
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
