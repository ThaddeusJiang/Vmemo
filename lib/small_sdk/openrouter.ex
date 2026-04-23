defmodule SmallSdk.OpenRouter do
  @moduledoc false
  require Logger

  alias SmallSdk.Utils

  @endpoint "https://openrouter.ai/api/v1/chat/completions"
  @default_receive_timeout_ms 120_000
  @default_caption_prompt "Describe this image in concise and accurate English."
  @fallback_model "openai/gpt-4o-mini"

  def chat(messages, opts \\ []) when is_list(messages) do
    api_key = Keyword.get(opts, :api_key)
    model = Keyword.get(opts, :model, @fallback_model)

    with :ok <- validate_api_key(api_key),
         req <- build_request(api_key) do
      case run_chat_completion_with_model(req, messages, model) do
        {:ok, content} ->
          {:ok, content}

        {:error, %Req.TransportError{reason: reason}} ->
          Logger.warning("OpenRouter request transport error: #{inspect(reason)}")
          {:error, reason}

        {:error, reason} = error ->
          maybe_retry_with_fallback_model(req, messages, model, reason, error)
      end
    else
      {:error, _} = error ->
        error
    end
  end

  def caption(image_base64, opts \\ []) when is_binary(image_base64) do
    prompt = Keyword.get(opts, :prompt, @default_caption_prompt)
    query(image_base64, prompt, opts)
  end

  def query(image_base64, prompt, opts \\ [])
      when is_binary(image_base64) and is_binary(prompt) do
    mime_type =
      Keyword.get(opts, :mime_type) ||
        Utils.detect_mime_type_from_base64(image_base64) ||
        "image/jpeg"

    messages = [
      %{
        role: "user",
        content: [
          %{type: "text", text: prompt},
          %{
            type: "image_url",
            image_url: %{url: "data:#{mime_type};base64,#{image_base64}"}
          }
        ]
      }
    ]

    chat(messages, opts)
  end

  defp run_chat_completion_with_model(req, messages, model) do
    payload = build_payload(messages, model)

    with {:ok, %{status: status, body: body}} <- Req.post(req, json: payload),
         {:ok, content} <- parse_response(status, body) do
      {:ok, content}
    end
  end

  defp maybe_retry_with_fallback_model(req, messages, model, reason, error) do
    if model != @fallback_model and provider_returned_error?(reason) do
      Logger.warning(
        "OpenRouter provider error on model=#{model}, retrying with fallback model=#{@fallback_model}"
      )

      run_chat_completion_with_model(req, messages, @fallback_model)
    else
      error
    end
  end

  defp validate_api_key(api_key) when is_binary(api_key) do
    if String.trim(api_key) == "", do: {:error, :missing_api_key}, else: :ok
  end

  defp validate_api_key(_), do: {:error, :missing_api_key}

  defp build_request(api_key) do
    Req.new(
      url: @endpoint,
      headers: [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{api_key}"}
      ],
      receive_timeout: @default_receive_timeout_ms
    )
  end

  defp build_payload(messages, model) do
    %{
      model: model,
      messages: messages
    }
  end

  defp parse_response(status, body) when status in 200..209 do
    text =
      body
      |> get_in(["choices", Access.at(0), "message", "content"])
      |> normalize_content()

    if is_binary(text) and String.trim(text) != "" do
      {:ok, String.trim(text)}
    else
      {:error, "Empty response from OpenRouter model"}
    end
  end

  defp parse_response(status, body) do
    {:error, extract_error_message(status, body)}
  end

  defp normalize_content(content) when is_binary(content), do: content

  defp normalize_content(content) when is_list(content) do
    content
    |> Enum.map(fn
      %{"type" => "text", "text" => text} when is_binary(text) -> text
      %{"text" => text} when is_binary(text) -> text
      %{text: text} when is_binary(text) -> text
      _ -> ""
    end)
    |> Enum.join(" ")
    |> String.trim()
  end

  defp normalize_content(_), do: nil

  defp provider_returned_error?(reason) when is_binary(reason) do
    reason
    |> String.downcase()
    |> String.contains?("provider returned error")
  end

  defp provider_returned_error?(_), do: false

  defp extract_error_message(status, body) do
    message =
      cond do
        is_map(body) and is_map(body["error"]) and is_binary(body["error"]["message"]) ->
          body["error"]["message"]

        is_map(body) and is_binary(body["error"]) ->
          body["error"]

        true ->
          "Request failed with status #{status}"
      end

    provider = get_in(body, ["error", "metadata", "provider_name"])
    raw = get_in(body, ["error", "metadata", "raw"])
    raw_provider_message = extract_raw_provider_message(raw)

    details =
      [raw_provider_message, provider && "provider: #{provider}"]
      |> Enum.filter(&present?/1)

    case details do
      [] -> message
      _ -> "#{message} (#{Enum.join(details, "; ")})"
    end
  end

  defp extract_raw_provider_message(raw) when is_binary(raw) do
    raw =
      raw
      |> String.trim()
      |> String.trim_leading("\"")
      |> String.trim_trailing("\"")
      |> String.replace("\\\"", "\"")

    case Jason.decode(raw) do
      {:ok, parsed} ->
        extract_raw_provider_message(parsed)

      _ ->
        nil
    end
  end

  defp extract_raw_provider_message(%{"error" => %{"message" => message}})
       when is_binary(message) and message != "",
       do: message

  defp extract_raw_provider_message(_), do: nil

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false
end
