defmodule Vmemo.Ts do
  alias SmallSdk.Typesense

  @doc """
  2024-12-20
  create photos collection
  """
  def change_1() do
    schema = %{
      "name" => "photos",
      "fields" => [
        %{"name" => "image", "type" => "image", "store" => false},
        %{"name" => "note", "type" => "string", "optional" => true},
        %{"name" => "url", "type" => "string"},
        %{"name" => "file_id", "type" => "string", "optional" => true},
        %{"name" => "inserted_at", "type" => "int64"},
        %{"name" => "inserted_by", "type" => "string"},
        # embedding
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
      ],
      "default_sorting_field" => "inserted_at"
    }

    Typesense.create_collection(schema)
    |> ensure_ok("create photos collection")
  end

  @doc """
  2024-12-20
  create notes collection, add note_ids to photos collection
  """
  def change_2() do
    notes_schema = %{
      "name" => "notes",
      "fields" => [
        %{"name" => "text", "type" => "string"},
        %{"name" => "photo_ids", "type" => "string[]", "optional" => true, "facet" => true},
        %{"name" => "inserted_at", "type" => "int64"},
        %{"name" => "updated_at", "type" => "int64"},
        %{"name" => "belongs_to", "type" => "string", "facet" => true}
      ],
      "default_sorting_field" => "inserted_at"
    }

    Typesense.create_collection(notes_schema)
    |> ensure_ok("create notes collection")

    photos_schema = %{
      "fields" => [
        %{"name" => "note_ids", "type" => "string[]", "optional" => true, "facet" => true}
      ]
    }

    Typesense.update_collection("photos", photos_schema)
    |> ensure_ok("update photos collection with note_ids")
  end

  @doc """
  add photos.ocr
  """
  def change_3() do
    schema = %{
      "fields" => [
        %{"name" => "_gen_ocr", "type" => "string", "optional" => true},
        %{"name" => "_gen_description", "type" => "string", "optional" => true}
      ]
    }

    Typesense.update_collection("photos", schema)
    |> ensure_ok("update photos collection with gen fields")
  end

  def reset do
    Typesense.drop_collection("photos")
    |> ensure_ok("drop photos collection")

    Typesense.drop_collection("notes")
    |> ensure_ok("drop notes collection")

    change_1()
    change_2()
    change_3()
  end

  defp ensure_ok({:ok, _}, _action), do: :ok
  defp ensure_ok({:error, "Not Found"}, _action), do: :ok
  defp ensure_ok({:error, reason}, action), do: raise("Typesense #{action} failed: #{reason}")
end
