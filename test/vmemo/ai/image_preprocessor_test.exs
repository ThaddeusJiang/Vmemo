defmodule Vmemo.Ai.ImagePreprocessorTest do
  use ExUnit.Case, async: false
  import Mock

  alias Vmemo.Ai.ImagePreprocessor

  @wall_e_path "test/support/fixtures/images/wall-e.png"

  test "returns original for small jpeg without requiring external tools" do
    binary = :crypto.strong_rand_bytes(10_000)

    assert {:ok, ^binary} = ImagePreprocessor.maybe_prepare_for_vision(binary, "image/jpeg")
  end

  test "returns original for gif" do
    binary = :crypto.strong_rand_bytes(900_000)

    assert {:ok, ^binary} = ImagePreprocessor.maybe_prepare_for_vision(binary, "image/gif")
  end

  test "raises when imagemagick executable is unavailable for large non-gif images" do
    binary = :crypto.strong_rand_bytes(900_000)

    with_mock SmallSdk.ImageMagick,
      preprocess_for_vision!: fn _binary, _mime_type, _opts ->
        raise "ImageMagick executable is required but not found (magick/convert)."
      end do
      assert_raise RuntimeError, ~r/ImageMagick executable is required but not found/, fn ->
        ImagePreprocessor.maybe_prepare_for_vision(binary, "image/png")
      end
    end
  end

  test "processes wall-e fixture into a smaller image using mocked image command" do
    original_binary = File.read!(@wall_e_path)

    with_mock SmallSdk.ImageMagick,
      preprocess_for_vision!: fn _binary, _mime_type, _opts ->
        binary_part(original_binary, 0, div(byte_size(original_binary), 2))
      end do
      {:ok, processed_binary} =
        ImagePreprocessor.maybe_prepare_for_vision(original_binary, "image/png")

      assert byte_size(processed_binary) < byte_size(original_binary)
    end
  end
end
