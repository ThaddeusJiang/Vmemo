defmodule Vmemo.Workers.Typesense.CreatePhoto do
  use Oban.Worker, queue: :sync_typesense, max_attempts: 3

  require Logger
  alias Vmemo.Photos.Photo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"photo_id" => photo_id}}) do
    with {:ok, _photo} <- Ash.get(Photo, photo_id, actor: nil, authorize?: false),
         {:ok, true} <- Photo.sync_typesense_by_id(photo_id, actor: nil, authorize?: false) do
      :ok
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
end
