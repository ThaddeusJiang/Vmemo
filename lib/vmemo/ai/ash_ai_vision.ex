defmodule Vmemo.Ai.AshAiVision do
  @moduledoc false

  import ReqLLM.Context

  alias ReqLLM.Message.ContentPart

  @default_caption_max_tokens 256
  @default_query_max_tokens 1024

  def caption(image_base64, opts \\ []) when is_binary(image_base64) do
    language = Keyword.get(opts, :language, "en")
    prompt = Keyword.get(opts, :prompt, default_caption_prompt(language))
    opts = Keyword.put_new(opts, :max_tokens, @default_caption_max_tokens)
    query(image_base64, prompt, opts)
  end

  def query(image_base64, prompt, opts \\ [])
      when is_binary(image_base64) and is_binary(prompt) do
    mime_type = Keyword.get(opts, :mime_type, "image/jpeg")
    max_tokens = normalize_max_tokens(Keyword.get(opts, :max_tokens, @default_query_max_tokens))

    with {:ok, model} <- opts |> Keyword.get(:model) |> normalize_model(),
         {:ok, image_binary} <- decode_base64_image(image_base64),
         {:ok, response} <-
           ReqLLM.generate_text(
             model,
             [
               user([
                 ContentPart.text(prompt),
                 ContentPart.image(image_binary, mime_type)
               ])
             ],
             temperature: 0.2,
             max_tokens: max_tokens
           ),
         text when is_binary(text) <- ReqLLM.Response.text(response),
         trimmed <- String.trim(text),
         true <- trimmed != "" do
      {:ok, trimmed}
    else
      {:error, reason} ->
        {:error, reason}

      false ->
        {:error, "Empty response from AshAi vision pipeline"}

      _ ->
        {:error, "Empty response from AshAi vision pipeline"}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp normalize_model(model) when is_binary(model) do
    model = String.trim(model)

    if model == "" do
      {:error, "Vision model is required"}
    else
      normalized =
        if String.contains?(model, ":") do
          model
        else
          "openrouter:" <> model
        end

      {:ok, normalized}
    end
  end

  defp normalize_model(_), do: {:error, "Vision model is required"}

  defp decode_base64_image(image_base64) do
    case Base.decode64(image_base64) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, "Invalid base64 image"}
    end
  end

  defp normalize_max_tokens(max_tokens) when is_integer(max_tokens) and max_tokens > 0,
    do: max_tokens

  defp normalize_max_tokens(_), do: @default_query_max_tokens

  defp default_caption_prompt(language) when is_binary(language) and language != "" do
    "Describe this image concisely and accurately. Reply in #{language}."
  end

  defp default_caption_prompt(_), do: "Describe this image concisely and accurately. Reply in en."
end
