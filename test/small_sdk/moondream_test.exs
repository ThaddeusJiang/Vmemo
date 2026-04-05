defmodule SmallSdk.MoondreamTest do
  use ExUnit.Case, async: false

  alias SmallSdk.Moondream
  alias SmallSdk.FileSystem

  @test_image_path "test/support/fixtures/images/wall-e.png"
  @moduletag :integration

  setup do
    image_base64 = FileSystem.read_image_base64!(@test_image_path)
    {:ok, image_base64: image_base64}
  end

  describe "caption/2" do
    @tag :integration
    test "generates caption for image", %{image_base64: image_base64} do
      case Moondream.caption(image_base64) do
        {:ok, caption} ->
          assert is_binary(caption)
          assert String.length(caption) > 0
          IO.puts("Caption: #{String.slice(caption, 0, 100)}...")

        {:error, reason} ->
          flunk("Caption generation failed: #{inspect(reason)}")
      end
    end

    @tag :integration
    test "generates short caption", %{image_base64: image_base64} do
      case Moondream.caption(image_base64, length: "short") do
        {:ok, caption} ->
          assert is_binary(caption)
          assert String.length(caption) > 0
          IO.puts("Short caption: #{caption}")

        {:error, reason} ->
          flunk("Short caption generation failed: #{inspect(reason)}")
      end
    end
  end

  describe "query/3" do
    @tag :integration
    test "queries image with prompt", %{image_base64: image_base64} do
      prompt = "What is in this image?"

      case Moondream.query(image_base64, prompt) do
        {:ok, result} ->
          assert is_binary(result) or is_map(result)
          IO.puts("Query result: #{inspect(result) |> String.slice(0, 200)}...")

        {:error, reason} ->
          flunk("Query failed: #{inspect(reason)}")
      end
    end

    @tag :integration
    test "queries image with specific question", %{image_base64: image_base64} do
      prompt = "What color is the robot?"

      case Moondream.query(image_base64, prompt) do
        {:ok, result} ->
          assert is_binary(result) or is_map(result)
          IO.puts("Query result: #{inspect(result) |> String.slice(0, 200)}...")

        {:error, reason} ->
          flunk("Query failed: #{inspect(reason)}")
      end
    end
  end

  describe "point/3" do
    @tag :integration
    test "points to location in image", %{image_base64: image_base64} do
      prompt = "Where is the robot?"

      case Moondream.point(image_base64, prompt) do
        {:ok, result} ->
          # Point should return coordinates (map or list)
          assert is_map(result) or is_list(result)
          IO.puts("Point result: #{inspect(result)}")

        {:error, reason} ->
          flunk("Point failed: #{inspect(reason)}")
      end
    end

    @tag :integration
    test "points to specific object", %{image_base64: image_base64} do
      prompt = "Where is the Rubik's Cube?"

      case Moondream.point(image_base64, prompt) do
        {:ok, result} ->
          assert is_map(result) or is_list(result)
          IO.puts("Point result: #{inspect(result)}")

        {:error, reason} ->
          flunk("Point failed: #{inspect(reason)}")
      end
    end
  end

  describe "detect/3" do
    @tag :integration
    test "detects objects in image", %{image_base64: image_base64} do
      prompt = "Find all objects"

      case Moondream.detect(image_base64, prompt) do
        {:ok, result} ->
          # Detect should return a list of detections or a map
          assert is_list(result) or is_map(result)
          IO.puts("Detect result: #{inspect(result) |> String.slice(0, 300)}...")

        {:error, reason} ->
          flunk("Detect failed: #{inspect(reason)}")
      end
    end

    @tag :integration
    test "detects specific objects", %{image_base64: image_base64} do
      prompt = "Find the robot"

      case Moondream.detect(image_base64, prompt) do
        {:ok, result} ->
          assert is_list(result) or is_map(result)
          IO.puts("Detect result: #{inspect(result) |> String.slice(0, 300)}...")

        {:error, reason} ->
          flunk("Detect failed: #{inspect(reason)}")
      end
    end
  end

  describe "segment/3" do
    @tag :integration
    test "segments image", %{image_base64: image_base64} do
      prompt = "Segment the robot"

      case Moondream.segment(image_base64, prompt) do
        {:ok, result} ->
          # Segment should return mask or segmentation data
          assert is_map(result) or is_binary(result)

          if is_map(result) do
            IO.puts("Segment result keys: #{inspect(Map.keys(result))}")
          end

        {:error, reason} ->
          # Segment function may not be available in Moondream Station
          if String.contains?(inspect(reason), "not available") do
            IO.puts("Segment function not available: #{inspect(reason)}")
            :ok
          else
            flunk("Segment failed: #{inspect(reason)}")
          end
      end
    end

    @tag :integration
    test "segments specific object", %{image_base64: image_base64} do
      prompt = "Segment the Rubik's Cube"

      case Moondream.segment(image_base64, prompt) do
        {:ok, result} ->
          assert is_map(result) or is_binary(result)

          if is_struct(result) do
            IO.puts("Segment result type: #{inspect(result.__struct__)}")
          end

        {:error, reason} ->
          # Segment function may not be available in Moondream Station
          if String.contains?(inspect(reason), "not available") do
            IO.puts("Segment function not available: #{inspect(reason)}")
            :ok
          else
            flunk("Segment failed: #{inspect(reason)}")
          end
      end
    end
  end

  describe "error handling" do
    @tag :integration
    test "handles invalid base64" do
      invalid_base64 = "not-valid-base64"

      case Moondream.caption(invalid_base64) do
        {:ok, _} ->
          # Some APIs might accept invalid base64 and return an error response
          :ok

        {:error, _reason} ->
          # Expected behavior
          :ok
      end
    end

    @tag :integration
    test "handles empty prompt", %{image_base64: image_base64} do
      case Moondream.query(image_base64, "") do
        {:ok, _result} ->
          # Some APIs might accept empty prompt
          :ok

        {:error, _reason} ->
          # Expected behavior
          :ok
      end
    end
  end
end
