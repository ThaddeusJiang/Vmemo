defmodule Mix.Tasks.Ts.WarmupEmbedding do
  @moduledoc false
  use Mix.Task

  alias SmallSdk.Typesense

  @shortdoc "Insert one image document to warm up Typesense embedding model"

  @tiny_png_base64 "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WnM7l8AAAAASUVORK5CYII="

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    Mix.Task.run("ts.migrate")

    document = %{
      "id" => "warmup-#{System.system_time(:millisecond)}",
      "image" => @tiny_png_base64,
      "note" => "embedding warmup",
      "url" => "http://localhost:4000/warmup.png",
      "inserted_at" => System.system_time(:second),
      "inserted_by" => "warmup"
    }

    case Typesense.create_document("memo_images", document) do
      {:ok, _doc} ->
        Mix.shell().info("Typesense embedding warmup document inserted")

      {:error, reason} ->
        Mix.raise("Typesense embedding warmup failed: #{inspect(reason)}")
    end
  end
end
