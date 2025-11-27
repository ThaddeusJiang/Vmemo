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

    req = build_request("/caption")

    res =
      Req.post(req,
        json: %{
          image_url: "data:image/jpeg;base64,#{image_base64}",
          length: length,
          stream: false
        }
      )

    handle_response(res)
  end

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
