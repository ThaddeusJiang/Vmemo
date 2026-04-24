defmodule Vmemo.Chat.AiRouter do
  @moduledoc false

  alias SmallSdk.Moondream
  alias Vmemo.Ai.AshAiVision
  alias Vmemo.Ai.VisionConfig
  alias Vmemo.Memo.Image

  @supported_tools ~w(query caption point detect segment)

  def route_image_tool(conversation, text, actor, scoped_image_id)
      when is_map(conversation) and is_binary(text) do
    image_id =
      cond do
        is_binary(conversation.image_id) ->
          conversation.image_id

        is_binary(scoped_image_id) ->
          scoped_image_id

        true ->
          nil
      end

    if is_binary(image_id) do
      case parse_tool_command(text) do
        {:ok, tool, prompt} ->
          run_tool(image_id, tool, prompt, actor)

        :skip ->
          if should_fallback_to_general_chat?(text) do
            :skip
          else
            run_tool(image_id, "query", String.trim(text), actor)
          end
      end
    else
      :skip
    end
  end

  def route_image_tool(_, _, _, _), do: :skip

  def tool_hint do
    """
    You can also use image commands in this image-scoped conversation:
    /caption
    /query <question>
    /point <object>
    /detect <object>
    /segment <prompt>
    """
  end

  defp parse_tool_command(text) do
    trimmed = String.trim(text)

    if String.starts_with?(trimmed, "/") do
      [tool | rest] =
        trimmed
        |> String.trim_leading("/")
        |> String.split(~r/\s+/, trim: true)
        |> case do
          [] -> [""]
          items -> items
        end

      tool = String.downcase(tool)
      prompt = rest |> Enum.join(" ") |> String.trim()

      if tool in @supported_tools do
        {:ok, tool, prompt}
      else
        :skip
      end
    else
      :skip
    end
  end

  # In image-scoped conversations, regular text should default to image query,
  # unless the user is explicitly asking to search for other images.
  defp should_fallback_to_general_chat?(text) when is_binary(text) do
    normalized = text |> String.trim() |> String.downcase()

    normalized == "" ||
      String.contains?(normalized, "other image") ||
      String.contains?(normalized, "other images") ||
      String.contains?(normalized, "search image") ||
      String.contains?(normalized, "search for image") ||
      String.contains?(normalized, "similar image") ||
      String.contains?(text, "其他图片") ||
      String.contains?(text, "其他图") ||
      String.contains?(text, "找图") ||
      String.contains?(text, "搜图")
  end

  defp run_tool(image_id, tool, prompt, actor) do
    with {:ok, image} <- Ash.get(Image, image_id, actor: actor),
         {:ok, {image_base64, mime_type}} <- read_image_as_base64(image.url),
         {:ok, result} <- call_tool(tool, image_base64, mime_type, prompt) do
      {:ok, %{provider: provider_for(tool), tool_name: tool, text: normalize_result(result)}}
    else
      {:error, reason} ->
        {:ok,
         %{
           provider: provider_for(tool),
           tool_name: tool,
           text: "Tool call failed: #{format_reason(reason)}"
         }}
    end
  end

  defp call_tool("caption", image_base64, mime_type, _prompt) do
    config = VisionConfig.resolve()
    AshAiVision.caption(image_base64, model: config.model, mime_type: mime_type)
  end

  defp call_tool("query", _image_base64, _mime_type, ""),
    do: {:error, "Prompt is required for /query"}

  defp call_tool("query", image_base64, mime_type, prompt) do
    config = VisionConfig.resolve()
    AshAiVision.query(image_base64, prompt, model: config.model, mime_type: mime_type)
  end

  defp call_tool("point", _image_base64, _mime_type, ""),
    do: {:error, "Prompt is required for /point"}

  defp call_tool("detect", _image_base64, _mime_type, ""),
    do: {:error, "Prompt is required for /detect"}

  defp call_tool("segment", _image_base64, _mime_type, ""),
    do: {:error, "Prompt is required for /segment"}

  defp call_tool("point", image_base64, mime_type, prompt),
    do: Moondream.point(image_base64, prompt, mime_type: mime_type)

  defp call_tool("detect", image_base64, mime_type, prompt),
    do: Moondream.detect(image_base64, prompt, mime_type: mime_type)

  defp call_tool("segment", image_base64, mime_type, prompt),
    do: Moondream.segment(image_base64, prompt, mime_type: mime_type)

  defp call_tool(_tool, _image_base64, _mime_type, _prompt), do: {:error, "Unsupported tool"}

  defp provider_for(tool) when tool in ["query", "caption"], do: "openrouter"
  defp provider_for(_tool), do: "moondream-station"

  defp normalize_result(result) when is_binary(result), do: String.trim(result)

  defp normalize_result(result) when is_map(result) or is_list(result) do
    Jason.encode_to_iodata!(result, pretty: true) |> IO.iodata_to_binary()
  end

  defp normalize_result(result), do: to_string(result)

  defp read_image_as_base64(url) when is_binary(url) do
    with {:ok, image_url} <- normalize_image_url(url),
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

  defp normalize_image_url(url) when is_binary(url) do
    parsed = URI.parse(url)

    if is_binary(parsed.scheme) do
      {:ok, url}
    else
      base_url = VmemoWeb.Endpoint.url()
      {:ok, base_url |> Kernel.<>("/") |> URI.merge(url) |> to_string()}
    end
  end

  defp detect_mime_type(binary) when is_binary(binary) do
    case binary do
      <<0xFF, 0xD8, _::binary>> -> "image/jpeg"
      <<0x89, 0x50, 0x4E, 0x47, _::binary>> -> "image/png"
      <<"GIF87a", _::binary>> -> "image/gif"
      <<"GIF89a", _::binary>> -> "image/gif"
      <<"RIFF", _::binary-size(4), "WEBP", _::binary>> -> "image/webp"
      _ -> "image/jpeg"
    end
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end
