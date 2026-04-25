defmodule Vmemo.Ai.ImageData do
  @moduledoc false

  def fetch_base64_from_url(url) when is_binary(url) do
    with {:ok, image_url} <- normalize_url(url),
         {:ok, response} <- Req.get(image_url),
         true <- response.status in 200..299,
         binary when is_binary(binary) <- response.body do
      mime_type = detect_mime_type(binary)
      {:ok, {Base.encode64(binary), mime_type}}
    else
      false ->
        {:error, "Failed to read image: unexpected response status"}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Failed to read image"}
    end
  end

  def normalize_url(url) when is_binary(url) do
    parsed = URI.parse(url)

    if is_binary(parsed.scheme) do
      {:ok, url}
    else
      base_url = VmemoWeb.Endpoint.url()
      {:ok, base_url |> Kernel.<>("/") |> URI.merge(url) |> to_string()}
    end
  end

  def detect_mime_type(binary) when is_binary(binary) do
    case binary do
      <<0xFF, 0xD8, _::binary>> -> "image/jpeg"
      <<0x89, 0x50, 0x4E, 0x47, _::binary>> -> "image/png"
      <<"GIF87a", _::binary>> -> "image/gif"
      <<"GIF89a", _::binary>> -> "image/gif"
      <<"RIFF", _::binary-size(4), "WEBP", _::binary>> -> "image/webp"
      _ -> "image/jpeg"
    end
  end
end
