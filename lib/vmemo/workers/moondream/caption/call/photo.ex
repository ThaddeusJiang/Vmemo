defmodule Vmemo.Workers.Moondream.Caption.Call.Photo do
  alias Vmemo.Photos.Photo
  alias Vmemo.Workers.Moondream.Caption.Image

  def prepare(%{"photo_id" => photo_id}) do
    case Ash.get(Photo, photo_id, actor: nil, authorize?: false) do
      {:ok, photo} ->
        if is_nil(photo.caption) or photo.caption == "" do
          with {:ok, image_base64} <- Image.read_as_base64(photo.url) do
            {:ok, %{photo: photo}, image_base64}
          else
            {:error, reason} -> {:error, %{photo: photo}, reason}
          end
        else
          {:skip, %{photo: photo}, :already_captioned}
        end

      {:error, reason} ->
        {:error, %{photo_id: photo_id}, reason}
    end
  end

  def prepare(_args), do: {:error, %{}, :invalid_args}
end
