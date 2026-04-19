# mix run priv/ts/migrations/2026-04-12.exs

defmodule Vmemo.Ts.Migrations.V20260412 do
  alias SmallSdk.Typesense

  def up do
    create_memo_images_collection()
    create_memo_notes_collection()
    :ok
  end

  defp create_memo_images_collection do
    schema = %{
      "name" => "memo_images",
      "fields" => [
        %{"name" => "image", "type" => "image", "store" => false},
        %{"name" => "note", "type" => "string", "optional" => true},
        %{"name" => "url", "type" => "string"},
        %{"name" => "file_id", "type" => "string", "optional" => true},
        %{"name" => "inserted_at", "type" => "int64"},
        %{"name" => "inserted_by", "type" => "string"},
        %{"name" => "note_ids", "type" => "string[]", "optional" => true, "facet" => true},
        %{"name" => "caption", "type" => "string", "optional" => true},
        %{"name" => "_purpose", "type" => "string", "optional" => true, "facet" => true},
        image_embedding_field()
      ],
      "default_sorting_field" => "inserted_at"
    }

    Typesense.create_collection(schema)
    |> ensure_collection_created("memo_images")
  end

  defp create_memo_notes_collection do
    schema = %{
      "name" => "memo_notes",
      "fields" => [
        %{"name" => "text", "type" => "string"},
        %{"name" => "image_ids", "type" => "string[]", "optional" => true, "facet" => true},
        %{"name" => "inserted_at", "type" => "int64"},
        %{"name" => "updated_at", "type" => "int64"},
        %{"name" => "belongs_to", "type" => "string", "facet" => true}
      ],
      "default_sorting_field" => "inserted_at"
    }

    Typesense.create_collection(schema)
    |> ensure_collection_created("memo_notes")
  end

  defp image_embedding_field do
    %{
      "name" => "image_embedding",
      "type" => "float[]",
      "embed" => %{
        "from" => ["image"],
        "model_config" => %{
          "model_name" => "ts/clip-vit-b-p32"
        }
      }
    }
  end

  defp ensure_collection_created({:ok, _}, _collection), do: :ok
  defp ensure_collection_created({:error, "Conflict"}, _collection), do: :ok

  defp ensure_collection_created(result, collection),
    do: ensure_ok(result, "create #{collection} collection")

  defp ensure_ok({:ok, _}, _action), do: :ok
  defp ensure_ok({:error, reason}, action), do: raise("Typesense #{action} failed: #{reason}")
end

Vmemo.Ts.Migrations.V20260412.up()
