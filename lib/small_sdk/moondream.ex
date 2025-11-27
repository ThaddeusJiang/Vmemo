defmodule SmallSdk.Moondream do
  require Logger

  alias SmallSdk.Utils

  @doc """
  Generate a caption for an image using Moondream Station.

  ## Parameters
    - image_base64: Base64 encoded image data
    - opts: Optional parameters
      - length: "short" or "normal" (default: "normal")

  ## Example

      iex> SmallSdk.Moondream.caption("iVBORw0KGgo...")
      {:ok, "A detailed description of the image..."}

      iex> SmallSdk.Moondream.caption("iVBORw0KGgo...", length: "short")
      {:ok, "A brief description."}
  """
  def caption(image_base64, opts \\ []) do
    length = Keyword.get(opts, :length, "normal")

    mime_type =
      Keyword.get(opts, :mime_type) ||
        detect_mime_type(image_base64) ||
        "image/jpeg"

    req = build_request("/caption")

    res =
      Req.post(req,
        json: %{
          image_url: "data:#{mime_type};base64,#{image_base64}",
          length: length,
          stream: false
        }
      )

    handle_response(res)
  end

  defp detect_mime_type(image_base64) do
    case Base.decode64(image_base64) do
      {:ok, binary} -> detect_mime_from_binary(binary)
      :error -> nil
    end
  end

  # JPEG: starts with FF D8 FF
  defp detect_mime_from_binary(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "image/jpeg"

  # PNG: starts with 89 50 4E 47 0D 0A 1A 0A
  defp detect_mime_from_binary(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>),
    do: "image/png"

  # GIF87a
  defp detect_mime_from_binary(<<"GIF87a", _::binary>>), do: "image/gif"

  # GIF89a
  defp detect_mime_from_binary(<<"GIF89a", _::binary>>), do: "image/gif"

  # WEBP: starts with RIFF....WEBP
  defp detect_mime_from_binary(<<"RIFF", _::binary-size(4), "WEBP", _::binary>>),
    do: "image/webp"

  defp detect_mime_from_binary(_), do: nil

  def get_env() do
    url =
      Application.fetch_env!(:vmemo, :moondream_url)
      |> Utils.validate_url!()

    {url}
  end

  defp build_request(path) do
    {url} = get_env()

    Req.new(
      base_url: url,
      url: path,
      headers: [
        {"Content-Type", "application/json"}
      ],
      receive_timeout: 120_000
    )
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    case status do
      status when status in 200..209 ->
        caption = body["caption"]
        {:ok, caption}

      _ ->
        Logger.warning("Moondream request failed with status #{status}: #{inspect(body)}")
        {:error, "Request failed with status #{status}"}
    end
  end

  defp handle_response({:error, reason}) do
    Logger.warning("Moondream request failed: #{inspect(reason)}")
    {:error, reason}
  end
end
