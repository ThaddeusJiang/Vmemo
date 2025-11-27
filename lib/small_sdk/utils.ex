defmodule SmallSdk.Utils do
  @moduledoc """
  Common utility functions for SmallSdk modules.
  """

  def validate_url!(url) do
    uri = URI.parse(url)

    if uri.scheme in ["http", "https"] and uri.host do
      url
    else
      raise ArgumentError, "Invalid URL: #{url}"
    end
  end

  @doc """
  Detect MIME type from base64 encoded image data.

  Returns the MIME type string (e.g., "image/jpeg") or nil if unknown.

  ## Examples

      iex> SmallSdk.Utils.detect_mime_type_from_base64(jpeg_base64)
      "image/jpeg"

      iex> SmallSdk.Utils.detect_mime_type_from_base64(invalid_base64)
      nil
  """
  def detect_mime_type_from_base64(image_base64) do
    case Base.decode64(image_base64) do
      {:ok, binary} -> detect_mime_type_from_binary(binary)
      :error -> nil
    end
  end

  @doc """
  Detect MIME type from binary image data using magic bytes.

  Supports JPEG, PNG, GIF, and WEBP formats.

  ## Examples

      iex> SmallSdk.Utils.detect_mime_type_from_binary(<<0xFF, 0xD8, 0xFF, ...>>)
      "image/jpeg"
  """
  def detect_mime_type_from_binary(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "image/jpeg"

  def detect_mime_type_from_binary(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>),
    do: "image/png"

  def detect_mime_type_from_binary(<<"GIF87a", _::binary>>), do: "image/gif"
  def detect_mime_type_from_binary(<<"GIF89a", _::binary>>), do: "image/gif"

  def detect_mime_type_from_binary(<<"RIFF", _::binary-size(4), "WEBP", _::binary>>),
    do: "image/webp"

  def detect_mime_type_from_binary(_), do: nil
end
