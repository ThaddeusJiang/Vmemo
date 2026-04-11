defmodule Vmemo.Ts.Schema do
  @moduledoc false

  alias SmallSdk.Typesense

  def change_1 do
    photos_schema = %{
      "name" => "photos",
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

    Typesense.create_collection(photos_schema)
    |> ensure_collection_created("photos")

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
  end

  @doc """
  Adds `_purpose` to `photos` for existing Typesense clusters (idempotent).
  Fresh installs already include this field via `change_1/0`.
  """
  def change_2 do
    ensure_photos_purpose_field()
  end

  @doc """
  Adds `_purpose` when an older migration only created `image_purpose` (idempotent).
  """
  def change_3 do
    ensure_photos_purpose_field()
  end

  def reset do
    migrations_collection =
      [Vmemo, Ts, SchemaMigrator]
      |> Module.concat()
      |> apply(:migrations_collection, [])

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

  defp ensure_ok({:ok, _}, _action), do: :ok
  defp ensure_ok({:error, "Not Found"}, _action), do: :ok
  defp ensure_ok({:error, reason}, action), do: raise("Typesense #{action} failed: #{reason}")

  defp ensure_photos_purpose_field do
    case Typesense.get_collection("photos") do
      {:ok, %{"fields" => fields}} when is_list(fields) ->
        if Enum.any?(fields, fn f -> Map.get(f, "name") == "_purpose" end) do
          :ok
        else
          Typesense.update_collection("photos", %{
            "fields" => [
              %{"name" => "_purpose", "type" => "string", "optional" => true, "facet" => true}
            ]
          })
          |> ensure_ok("add _purpose field to photos collection")
        end

      {:ok, other} ->
        raise("Typesense photos collection schema missing fields: #{inspect(Map.keys(other))}")

      {:error, reason} ->
        raise("Typesense get_collection photos failed: #{reason}")
    end
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
end
