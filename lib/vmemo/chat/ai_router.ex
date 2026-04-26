defmodule Vmemo.Chat.AiRouter do
  @moduledoc false

  alias SmallSdk.Moondream
  alias Vmemo.Ai.AshAiVision
  alias Vmemo.Ai.ImageData
  alias Vmemo.Ai.VisionConfig
  alias Vmemo.Memo.Image

  @supported_tools ~w(query caption point detect segment)

  def route_image_tool(conversation, text, actor)
      when is_map(conversation) and is_binary(text) do
    route_image_tool(conversation, text, actor, nil)
  end

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

  # Regular text in a chat with active image context defaults to /query.
  # We only fall back to general chat when the user intent is clearly image search across library.
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
         {:ok, {image_base64, mime_type}} <- ImageData.fetch_base64_from_url(image.url),
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

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end
