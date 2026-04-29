defmodule Vmemo.Ai.ImagePreprocessorTest do
  use ExUnit.Case, async: true

  alias Vmemo.Ai.ImagePreprocessor
  @wall_e_path "test/support/fixtures/images/wall-e.png"
  @manual_output_dir Path.join(System.tmp_dir!(), "vmemo-vision-preprocess-manual")

  test "returns original for small jpeg without requiring external tools" do
    binary = :crypto.strong_rand_bytes(10_000)

    assert {:ok, ^binary} = ImagePreprocessor.maybe_prepare_for_vision(binary, "image/jpeg")
  end

  test "returns original for gif" do
    binary = :crypto.strong_rand_bytes(900_000)

    assert {:ok, ^binary} = ImagePreprocessor.maybe_prepare_for_vision(binary, "image/gif")
  end

  test "processes wall-e fixture into a smaller image for manual visual verification" do
    unless imagemagick_available?() do
      flunk(
        "ImageMagick is required for this test. Install it first (e.g. brew install imagemagick)."
      )
    end

    original_binary = File.read!(@wall_e_path)

    {:ok, processed_binary} =
      ImagePreprocessor.maybe_prepare_for_vision(original_binary, "image/png")

    assert byte_size(processed_binary) < byte_size(original_binary)

    File.mkdir_p!(@manual_output_dir)

    original_out_path = Path.join(@manual_output_dir, "wall-e-original.png")
    processed_out_path = Path.join(@manual_output_dir, "wall-e-processed.png")

    File.write!(original_out_path, original_binary)
    File.write!(processed_out_path, processed_binary)

    IO.puts("""
    Manual verification files:
      Original:  #{original_out_path}
      Processed: #{processed_out_path}
      Original size:  #{byte_size(original_binary)} bytes
      Processed size: #{byte_size(processed_binary)} bytes
    """)
  end

  defp imagemagick_available? do
    :os.find_executable(~c"magick") != false or :os.find_executable(~c"convert") != false
  end
end
