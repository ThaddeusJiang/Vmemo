defmodule Vmemo.Workers.Moondream.Caption.Call.Request do
  alias Vmemo.Photos.Photo
  alias Vmemo.Photos.PhotoCaptionRequest
  alias Vmemo.Workers.Moondream.Caption.Image

  def prepare(%{"request_id" => request_id}) do
    with {:ok, request} <- Ash.get(PhotoCaptionRequest, request_id, actor: nil),
         {:ok, request} <-
           PhotoCaptionRequest.update(request, %{status: "processing"}, actor: nil),
         {:ok, photo} <- Ash.get(Photo, request.photo_id, actor: nil),
         {:ok, image_base64} <- Image.read_as_base64(photo.url) do
      {:ok, %{request: request, photo: photo}, image_base64}
    else
      {:error, reason} ->
        {:error, %{request_id: request_id}, reason}
    end
  end

  def prepare(_args), do: {:error, %{}, :invalid_args}
end
