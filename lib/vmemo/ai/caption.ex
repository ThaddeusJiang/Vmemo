defmodule Vmemo.Ai.Caption do
  @moduledoc false

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

  alias SmallSdk.OpenRouter
  alias Vmemo.Ai.VisionConfig

  def generate_caption(image_base64, opts \\ []) do
    config = VisionConfig.resolve()
    mime_type = Keyword.get(opts, :mime_type)

    with {:ok, caption} <-
           OpenRouter.caption(
             image_base64,
             api_key: config.api_key,
             model: config.model,
             mime_type: mime_type
           ) do
      {:ok, caption}
    else
      {:error, reason} ->
        handle_caption_error(reason)
    end
  rescue
    e -> handle_caption_error(e)
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
end
