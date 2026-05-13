defmodule Vmemo.Ai.Caption do
  @moduledoc false

  import ReqLLM.Context, only: [user: 1]

  @unreachable_reasons [
    :connection_refused,
    :econnrefused,
    :host_unreachable,
    :ehostunreach,
    :enetunreach,
    :nxdomain,
    :eai_nodata,
    :eai_noname,
    :timeout
  ]

  alias Vmemo.Account
  alias Vmemo.Ai.AshAiVision
  alias Vmemo.Ai.VisionConfig
  alias Vmemo.Memo.Tag

  @tag_max_tokens 128
  @caption_with_tags_max_tokens 512

  defmodule CaptionTagResult do
    @moduledoc false

    use Ash.TypedStruct

    typed_struct do
      field :caption, :string, allow_nil?: false
      field :tags, {:array, :string}, allow_nil?: false, default: []
    end
  end

  def generate_caption(image_base64, opts \\ []) do
    config = VisionConfig.resolve()
    mime_type = Keyword.get(opts, :mime_type)
    language = resolve_language(Keyword.get(opts, :user_id))

    case AshAiVision.caption(
           image_base64,
           model: config.model,
           mime_type: mime_type,
           language: language
         ) do
      {:ok, caption} ->
        {:ok, caption}

      {:error, reason} ->
        handle_caption_error(reason)
    end
  rescue
    e -> handle_caption_error(e)
  end

  @spec generate_caption_and_tags(binary(), keyword()) ::
          {:ok, %{caption: binary(), tags: [binary()]}} | {:error | :discard, term()}
  def generate_caption_and_tags(image_base64, opts \\ []) do
    config = VisionConfig.resolve()
    mime_type = Keyword.get(opts, :mime_type)
    user_id = Keyword.get(opts, :user_id)
    language = resolve_language(user_id)
    existing_tags = existing_tags_for_user(user_id)

    prompt = """
    Analyze this image and return strict JSON object with keys:
    - "caption": concise, accurate image description text
    - "tags": array of 1-5 concise tag strings (no # characters)

    Rules:
    - Reply in preferred language when possible: #{language}.
    - Prefer existing tags first when suitable.
    - Only create new tags when existing tags are clearly unsuitable.
    - Keep tags short, deduplicated, and meaningful.
    - Output JSON only, no markdown.
    Existing tags: #{Jason.encode!(existing_tags)}.
    """

    schema = [
      caption: [type: :string, required: true],
      tags: [type: {:list, :string}, required: true]
    ]

    with {:ok, result} <-
           AshAiVision.generate_object(
             image_base64,
             prompt,
             schema,
             model: config.model,
             mime_type: mime_type,
             max_tokens: @caption_with_tags_max_tokens
           ),
         {:ok, payload} <- build_caption_and_tags_payload(result, existing_tags) do
      {:ok, payload}
    else
      {:error, reason} -> handle_caption_error(reason)
    end
  rescue
    e -> handle_caption_error(e)
  end

  @spec suggest_tags_from_caption(binary() | nil, keyword()) ::
          {:ok, [binary()]} | {:error, term()}
  def suggest_tags_from_caption(caption, opts \\ [])

  def suggest_tags_from_caption(caption, _opts)
      when not is_binary(caption) or caption == "",
      do: {:ok, []}

  def suggest_tags_from_caption(caption, opts) do
    user_id = Keyword.get(opts, :user_id)
    language = resolve_language(user_id)
    existing_tags = existing_tags_for_user(user_id)
    model = Application.fetch_env!(:vmemo, :openrouter_chat_model)

    prompt = """
    Extract 1-5 concise tag phrases from the caption below.
    Output strict JSON array of strings only.
    Do not include # characters.
    Prefer choosing from existing tags first when appropriate.
    You may create new tags only when existing tags are clearly not suitable.
    Keep original language when possible. Preferred language: #{language}.
    Existing tags: #{Jason.encode!(existing_tags)}.

    Caption:
    #{caption}
    """

    with {:ok, response} <-
           ReqLLM.generate_text(model, [user(prompt)], max_tokens: @tag_max_tokens),
         text when is_binary(text) <- ReqLLM.Response.text(response),
         {:ok, decoded} <- Jason.decode(String.trim(text)),
         tags when is_list(tags) <- decoded do
      {:ok, normalize_suggested_tags(tags, existing_tags)}
    else
      _ -> {:ok, []}
    end
  end

  defp handle_caption_error(:file_not_found), do: {:discard, :file_not_found}

  defp handle_caption_error("Request failed with status 401"),
    do: {:discard, "Request failed with status 401"}

  defp handle_caption_error("Request failed with status 403"),
    do: {:discard, "Request failed with status 403"}

  defp handle_caption_error("Request failed with status 404"),
    do: {:discard, "Request failed with status 404"}

  defp handle_caption_error(:missing_api_key), do: {:discard, :missing_api_key}

  defp handle_caption_error(:connection_refused), do: {:error, :vision_service_unreachable}

  defp handle_caption_error(%Req.TransportError{reason: reason})
       when reason in @unreachable_reasons,
       do: {:error, :vision_service_unreachable}

  defp handle_caption_error(reason) when is_atom(reason) and reason in @unreachable_reasons,
    do: {:error, :vision_service_unreachable}

  defp handle_caption_error(reason) when is_binary(reason) do
    reason_downcase = String.downcase(reason)

    cond do
      String.contains?(reason_downcase, "connection_refused") ->
        {:error, :vision_service_unreachable}

      String.contains?(reason_downcase, "connection refused") ->
        {:error, :vision_service_unreachable}

      true ->
        {:error, reason}
    end
  end

  defp handle_caption_error(reason), do: {:error, reason}

  defp build_caption_and_tags_payload(%ReqLLM.Response{object: object}, existing_tags)
       when is_map(object) do
    build_caption_and_tags_payload(object, existing_tags)
  end

  defp build_caption_and_tags_payload(%ReqLLM.Response{}, _existing_tags) do
    {:error, "Invalid structured response"}
  end

  defp build_caption_and_tags_payload(result, existing_tags) when is_map(result) do
    result =
      case result do
        %{object: object} when is_map(object) -> object
        other -> other
      end

    caption =
      result
      |> Map.get(:caption, Map.get(result, "caption"))
      |> to_string()
      |> String.trim()

    tags =
      result
      |> Map.get(:tags, Map.get(result, "tags", []))
      |> normalize_suggested_tags(existing_tags)

    if caption == "" do
      {:error, "Empty caption from structured response"}
    else
      payload = %CaptionTagResult{caption: caption, tags: tags}
      {:ok, %{caption: payload.caption, tags: payload.tags}}
    end
  end

  defp resolve_language(user_id) when is_binary(user_id) do
    Account.preferred_language(%{id: user_id})
  end

  defp resolve_language(_), do: "en"

  defp normalize_suggested_tags(tags, existing_tags) do
    canonical_existing =
      existing_tags
      |> Enum.reduce(%{}, fn tag, acc -> Map.put(acc, String.downcase(tag), tag) end)

    tags
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.replace(&1, ~r/\s+/u, " "))
    |> Enum.map(fn tag -> Map.get(canonical_existing, String.downcase(tag), tag) end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.take(5)
  end

  defp existing_tags_for_user(user_id) when is_binary(user_id) do
    Tag
    |> Ash.Query.load(:images)
    |> Ash.read!(actor: nil, authorize?: false)
    |> Enum.filter(fn tag ->
      tag.images
      |> List.wrap()
      |> Enum.any?(&(&1.user_id == user_id))
    end)
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end

  defp existing_tags_for_user(_), do: []
end
