defmodule Vmemo.Ts.Collections do
  @moduledoc false

  alias SmallSdk.Typesense

  def change_1 do
    fields = [
      %{"name" => "image", "type" => "image", "store" => false},
      %{"name" => "note", "type" => "string", "optional" => true},
      %{"name" => "url", "type" => "string"},
      %{"name" => "file_id", "type" => "string", "optional" => true},
      %{"name" => "inserted_at", "type" => "int64"},
      %{"name" => "inserted_by", "type" => "string"}
    ]

    schema = %{
      "name" => "photos",
      "fields" => fields ++ [image_embedding_field()],
      "default_sorting_field" => "inserted_at"
    }

    Typesense.create_collection(schema)
    |> ensure_collection_created("photos")
  end

  def change_2 do
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
    |> ensure_collection_created("notes")

    ensure_collection_fields(
      "photos",
      [%{"name" => "note_ids", "type" => "string[]", "optional" => true, "facet" => true}],
      "update photos collection with note_ids"
    )
  end

  def change_3 do
    ensure_collection_fields(
      "photos",
      [
        %{"name" => "_gen_ocr", "type" => "string", "optional" => true},
        %{"name" => "_gen_description", "type" => "string", "optional" => true}
      ],
      "update photos collection with gen fields"
    )
  end

  def change_4 do
    caption_field = %{"name" => "caption", "type" => "string", "optional" => true}

    ensure_collection_fields(
      "photos",
      [caption_field, image_embedding_field()],
      "update photos collection with caption and embedding fields"
    )
  end

  def reset do
    migrations_collection = Vmemo.Ts.Migrations.migrations_collection()

    Typesense.drop_collection("photos")
    |> ensure_ok("drop photos collection")

    Typesense.drop_collection("notes")
    |> ensure_ok("drop notes collection")

    Typesense.drop_collection(migrations_collection)
    |> ensure_ok("drop typesense migration tracking collection")
  end

  def ensure_migrations_collection(migrations_collection) do
    schema = %{
      "name" => migrations_collection,
      "fields" => [
        %{"name" => "version", "type" => "string"},
        %{"name" => "inserted_at", "type" => "int64"}
      ],
      "default_sorting_field" => "inserted_at"
    }

    Typesense.create_collection(schema)
    |> ensure_collection_created(migrations_collection)
  end

  def record_migration_version(migrations_collection, version) do
    document = %{
      "id" => version,
      "version" => version,
      "inserted_at" => System.system_time(:second)
    }

    case Typesense.create_document(migrations_collection, document) do
      {:ok, _} -> :ok
      {:error, "Conflict"} -> :ok
      {:error, reason} -> raise("Typesense record migration version failed: #{reason}")
    end
  end

  def applied_migration_versions(migrations_collection) do
    load_applied_migration_versions(migrations_collection, 1, MapSet.new())
  end

  defp load_applied_migration_versions(migrations_collection, page, acc) do
    case Typesense.list_documents!(migrations_collection, 100, page) do
      {:ok, docs} when is_list(docs) ->
        next_acc = Enum.reduce(docs, acc, &put_migration_version/2)
        maybe_load_next_migration_page(migrations_collection, page, docs, next_acc)

      {:ok, _other} ->
        acc

      {:error, "Not Found"} ->
        acc

      {:error, reason} ->
        raise("Typesense list migration versions failed: #{reason}")
    end
  end

  defp put_migration_version(doc, set) do
    case Map.get(doc, "version") do
      version when is_binary(version) -> MapSet.put(set, version)
      _ -> set
    end
  end

  defp maybe_load_next_migration_page(migrations_collection, page, docs, acc) do
    if length(docs) < 100 do
      acc
    else
      load_applied_migration_versions(migrations_collection, page + 1, acc)
    end
  end

  defp ensure_collection_created({:ok, _}, _collection), do: :ok
  defp ensure_collection_created({:error, "Conflict"}, _collection), do: :ok

  defp ensure_collection_created(result, collection),
    do: ensure_ok(result, "create #{collection} collection")

  defp ensure_collection_updated({:ok, _}, _action), do: :ok
  defp ensure_collection_updated({:error, "Not Found"}, _action), do: :ok

  defp ensure_collection_updated({:error, reason}, action) when is_binary(reason) do
    if String.contains?(reason, "is already part of the schema") do
      :ok
    else
      ensure_ok({:error, reason}, action)
    end
  end

  defp ensure_ok({:ok, _}, _action), do: :ok
  defp ensure_ok({:error, "Not Found"}, _action), do: :ok
  defp ensure_ok({:error, reason}, action), do: raise("Typesense #{action} failed: #{reason}")

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

  defp ensure_collection_fields(collection_name, fields, action) when is_list(fields) do
    existing_field_names = collection_field_names(collection_name)

    missing_fields =
      Enum.reject(fields, fn field ->
        field_name = Map.get(field, "name")
        Enum.member?(existing_field_names, field_name)
      end)

    if missing_fields == [] do
      :ok
    else
      schema = %{"fields" => missing_fields}

      Typesense.update_collection(collection_name, schema)
      |> ensure_collection_updated(action)
    end
  end

  defp collection_field_names(collection_name) do
    case Typesense.get_collection(collection_name) do
      {:ok, %{"fields" => fields}} when is_list(fields) ->
        fields
        |> Enum.map(&Map.get(&1, "name"))
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end
end
