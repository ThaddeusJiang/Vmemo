defmodule Vmemo.Ts.Warmup do
  alias SmallSdk.Typesense

  @embedding_warmup_receive_timeout 300_000
  @embedding_warmup_max_attempts 5
  @embedding_warmup_retry_sleep_ms 2_000
  @embedding_warmup_image_data "iVBORw0KGgoAAAANSUhEUgAAAGQAAABkCAIAAAD/gAIDAAABFUlEQVR4nO3OUQkAIABEsetfWiv4Nx4IC7Cd7XvkByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIX4Q4gchfhDiByF+EOIHIReeLesrH9s1agAAAABJRU5ErkJggg=="

  def ensure_image_embedding_model_ready do
    warmup_id = "__embedding_warmup_#{System.system_time(:millisecond)}"

    payload = %{
      "id" => warmup_id,
      "image" => @embedding_warmup_image_data,
      "url" => "warmup://embedding",
      "inserted_at" => System.system_time(:second),
      "inserted_by" => "__system__"
    }

    case create_warmup_document(payload, @embedding_warmup_max_attempts) do
      :ok ->
        _ = Typesense.delete_document("photos", warmup_id)
        :ok

      {:error, reason} ->
        raise("Typesense image embedding warmup failed: #{reason}")
    end
  end

  defp create_warmup_document(_payload, 0), do: {:error, "retries exhausted"}

  defp create_warmup_document(payload, attempts_left) do
    req = Typesense.build_request("/collections/photos/documents")

    result =
      Typesense.request(:post, req,
        json: payload,
        receive_timeout: @embedding_warmup_receive_timeout
      )
      |> Typesense.handle_response()

    case result do
      {:ok, _doc} ->
        :ok

      {:error, reason} when attempts_left > 1 ->
        if retriable_warmup_error?(reason) do
          Process.sleep(@embedding_warmup_retry_sleep_ms)
          create_warmup_document(payload, attempts_left - 1)
        else
          {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp retriable_warmup_error?(reason) do
    text = to_string(reason)

    String.contains?(text, "Service Unavailable") or
      String.contains?(text, "Req.TransportError")
  end
end
