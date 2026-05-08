defmodule Vmemo.Chat.AiRouter do
  @moduledoc false

  alias SmallSdk.Moondream
  alias Vmemo.Account
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
    case select_image_id(conversation, scoped_image_id) do
      image_id when is_binary(image_id) ->
        route_with_image_id(image_id, text, actor)

      _ ->
        :skip
    end
  end

  def route_image_tool(_, _, _, _), do: :skip

  defp select_image_id(conversation, scoped_image_id) do
    cond do
      is_binary(conversation.image_id) -> conversation.image_id
      is_binary(scoped_image_id) -> scoped_image_id
      true -> nil
    end
  end

  defp route_with_image_id(image_id, text, actor) do
    case parse_tool_command(text) do
      {:ok, tool, prompt} ->
        run_tool(image_id, tool, prompt, actor)

      :skip ->
        route_default_query_or_skip(image_id, text, actor)
    end
  end

  defp route_default_query_or_skip(image_id, text, actor) do
    if should_fallback_to_general_chat?(text) do
      :skip
    else
      run_tool(image_id, "query", String.trim(text), actor)
    end
  end

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

    normalized == "" or
      contains_any?(normalized, [
        "other image",
        "other images",
        "search image",
        "search for image",
        "similar image"
      ]) or
      contains_any?(text, ["其他图片", "其他图", "找图", "搜图"])
  end

  defp contains_any?(text, keywords) do
    Enum.any?(keywords, &String.contains?(text, &1))
  end

  defp run_tool(image_id, tool, prompt, actor) do
    with {:ok, image} <- Ash.get(Image, image_id, actor: actor),
         {:ok, {image_base64, mime_type}} <- ImageData.fetch_base64_from_url(image.url),
         {:ok, result} <- call_tool(tool, image_base64, mime_type, prompt, actor) do
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

  defp call_tool("caption", image_base64, mime_type, _prompt, actor) do
    config = VisionConfig.resolve()

    AshAiVision.caption(
      image_base64,
      model: config.model,
      mime_type: mime_type,
      language: Account.preferred_language(actor)
    )
  end

  defp call_tool("query", _image_base64, _mime_type, "", _actor),
    do: {:error, "Prompt is required for /query"}

  defp call_tool("query", image_base64, mime_type, prompt, _actor) do
    config = VisionConfig.resolve()
    AshAiVision.query(image_base64, prompt, model: config.model, mime_type: mime_type)
  end

  defp call_tool("point", _image_base64, _mime_type, "", _actor),
    do: {:error, "Prompt is required for /point"}

  defp call_tool("detect", _image_base64, _mime_type, "", _actor),
    do: {:error, "Prompt is required for /detect"}

  defp call_tool("segment", _image_base64, _mime_type, "", _actor),
    do: {:error, "Prompt is required for /segment"}

  defp call_tool("point", image_base64, mime_type, prompt, _actor),
    do: Moondream.point(image_base64, prompt, mime_type: mime_type)

  defp call_tool("detect", image_base64, mime_type, prompt, _actor),
    do: Moondream.detect(image_base64, prompt, mime_type: mime_type)

  defp call_tool("segment", image_base64, mime_type, prompt, _actor),
    do: Moondream.segment(image_base64, prompt, mime_type: mime_type)

  defp call_tool(_tool, _image_base64, _mime_type, _prompt, _actor),
    do: {:error, "Unsupported tool"}

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
