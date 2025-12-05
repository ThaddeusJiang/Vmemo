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
        Utils.detect_mime_type_from_base64(image_base64) ||
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

  @doc """
  Query an image with a prompt using Moondream Station.

  ## Parameters
    - image_base64: Base64 encoded image data
    - prompt: The query prompt text
    - opts: Optional parameters
      - mime_type: Image MIME type (auto-detected if not provided)

  ## Example

      iex> SmallSdk.Moondream.query("iVBORw0KGgo...", "What is in this image?")
      {:ok, "The image shows..."}
  """
  def query(image_base64, prompt, opts \\ []) do
    mime_type =
      Keyword.get(opts, :mime_type) ||
        Utils.detect_mime_type_from_base64(image_base64) ||
        "image/jpeg"

    req = build_request("/query")

    res =
      Req.post(req,
        json: %{
          image_url: "data:#{mime_type};base64,#{image_base64}",
          question: prompt,
          stream: false
        }
      )

    handle_response(res, :query)
  end

  @doc """
  Point to a location in an image based on a prompt using Moondream Station.

  ## Parameters
    - image_base64: Base64 encoded image data
    - prompt: The point prompt text
    - opts: Optional parameters
      - mime_type: Image MIME type (auto-detected if not provided)

  ## Example

      iex> SmallSdk.Moondream.point("iVBORw0KGgo...", "Where is the cat?")
      {:ok, %{"x" => 100, "y" => 200}}
  """
  def point(image_base64, prompt, opts \\ []) do
    mime_type =
      Keyword.get(opts, :mime_type) ||
        Utils.detect_mime_type_from_base64(image_base64) ||
        "image/jpeg"

    req = build_request("/point")

    res =
      Req.post(req,
        json: %{
          image_url: "data:#{mime_type};base64,#{image_base64}",
          object: prompt,
          stream: false
        }
      )

    handle_response(res, :point)
  end

  @doc """
  Detect objects in an image based on a prompt using Moondream Station.

  ## Parameters
    - image_base64: Base64 encoded image data
    - prompt: The detection prompt text
    - opts: Optional parameters
      - mime_type: Image MIME type (auto-detected if not provided)

  ## Example

      iex> SmallSdk.Moondream.detect("iVBORw0KGgo...", "Find all cars")
      {:ok, [%{"label" => "car", "bbox" => [10, 20, 100, 200]}, ...]}
  """
  def detect(image_base64, prompt, opts \\ []) do
    mime_type =
      Keyword.get(opts, :mime_type) ||
        Utils.detect_mime_type_from_base64(image_base64) ||
        "image/jpeg"

    req = build_request("/detect")

    res =
      Req.post(req,
        json: %{
          image_url: "data:#{mime_type};base64,#{image_base64}",
          object: prompt,
          stream: false
        }
      )

    handle_response(res, :detect)
  end

  @doc """
  Segment an image based on a prompt using Moondream Station.

  ## Parameters
    - image_base64: Base64 encoded image data
    - prompt: The segmentation prompt text
    - opts: Optional parameters
      - mime_type: Image MIME type (auto-detected if not provided)

  ## Example

      iex> SmallSdk.Moondream.segment("iVBORw0KGgo...", "Segment the person")
      {:ok, %{"mask" => "base64_encoded_mask", ...}}
  """
  def segment(image_base64, prompt, opts \\ []) do
    mime_type =
      Keyword.get(opts, :mime_type) ||
        Utils.detect_mime_type_from_base64(image_base64) ||
        "image/jpeg"

    req = build_request("/segment")

    res =
      Req.post(req,
        json: %{
          image_url: "data:#{mime_type};base64,#{image_base64}",
          prompt: prompt,
          stream: false
        }
      )

    handle_response(res, :segment)
  end

  defp handle_response(response, function_type \\ :caption)

  defp handle_response({:ok, %{status: status, body: body}}, function_type) do
    case status do
      status when status in 200..209 ->
        # Check if body contains an error message
        if is_map(body) and Map.has_key?(body, "error") do
          error_msg = body["error"]
          Logger.warning("Moondream #{function_type} returned error: #{error_msg}")
          {:error, error_msg}
        else
          result = extract_result(body, function_type)
          {:ok, result}
        end

      _ ->
        Logger.warning(
          "Moondream #{function_type} request failed with status #{status}: #{inspect(body)}"
        )

        {:error, "Request failed with status #{status}"}
    end
  end

  defp handle_response({:error, reason}, function_type) do
    Logger.warning("Moondream #{function_type} request failed: #{inspect(reason)}")
    {:error, reason}
  end

  defp extract_result(body, :caption) do
    body["caption"]
  end

  defp extract_result(body, :query) do
    # Query may return text or structured data
    body["answer"] || body["response"] || body["text"] || body
  end

  defp extract_result(body, :point) do
    # Point returns coordinates in points array
    case body do
      %{"points" => [point | _]} -> point
      %{"point" => point} -> point
      %{"coordinates" => coords} -> coords
      other -> other
    end
  end

  defp extract_result(body, :detect) do
    # Detect returns a list of detections
    body["detections"] || body["objects"] || body["results"] || body
  end

  defp extract_result(body, :segment) do
    # Segment returns mask or segmentation data
    body["mask"] || body["segmentation"] || body["result"] || body
  end
end
