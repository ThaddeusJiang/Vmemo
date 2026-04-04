defmodule Vmemo.Ts do
  alias SmallSdk.Typesense

  @migrations_glob "priv/ts/migrations/*.exs"
  @migrations_collection "ts_schema_migrations"
  @list_documents_page_size 100

  @doc """
  2024-12-20
  create photos collection
  """
  def change_1() do
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
    |> ensure_collection_created("notes")

    ensure_collection_fields(
      "photos",
      [%{"name" => "note_ids", "type" => "string[]", "optional" => true, "facet" => true}],
      "update photos collection with note_ids"
    )
  end

  @doc """
  add photos.ocr
  """
  def change_3() do
    ensure_collection_fields(
      "photos",
      [
        %{"name" => "_gen_ocr", "type" => "string", "optional" => true},
        %{"name" => "_gen_description", "type" => "string", "optional" => true}
      ],
      "update photos collection with gen fields"
    )
  end

  @doc """
  add photos.caption and optional image embedding field
  """
  def change_4() do
    caption_field = %{"name" => "caption", "type" => "string", "optional" => true}

    ensure_collection_fields(
      "photos",
      [caption_field, image_embedding_field()],
      "update photos collection with caption and embedding fields"
    )
  end

  def reset do
    Typesense.drop_collection("photos")
    |> ensure_ok("drop photos collection")

    Typesense.drop_collection("notes")
    |> ensure_ok("drop notes collection")

    Typesense.drop_collection(@migrations_collection)
    |> ensure_ok("drop typesense migration tracking collection")
  end

  def migrate do
    ensure_migrations_collection()
    applied_versions = applied_migration_versions()

    migration_entries()
    |> validate_unique_migration_versions()
    |> pending_migrations(applied_versions)
    |> Enum.each(fn %{version: version, path: path} ->
      Code.eval_file(path)
      record_migration_version(version)
    end)

    :ok
  end

  @doc """
  Build ordered pending migration entries from migration files and applied versions.
  """
  def pending_migrations(migration_entries, applied_versions) do
    applied_versions = MapSet.new(applied_versions)

    migration_entries
    |> Enum.sort_by(& &1.version)
    |> Enum.reject(fn %{version: version} -> MapSet.member?(applied_versions, version) end)
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

  defp ensure_collection_updated(result, action), do: ensure_ok(result, action)

  defp ensure_ok({:ok, _}, _action), do: :ok
  defp ensure_ok({:error, "Not Found"}, _action), do: :ok
  defp ensure_ok({:error, reason}, action), do: raise("Typesense #{action} failed: #{reason}")

  defp migration_entries do
    @migrations_glob
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(fn path ->
      %{
        version: Path.basename(path, ".exs"),
        path: path
      }
    end)
  end

  @doc """
  Validate migration versions are unique and return entries unchanged.
  """
  def validate_unique_migration_versions(entries) do
    versions = Enum.map(entries, & &1.version)

    case versions -- Enum.uniq(versions) do
      [] ->
        entries

      duplicated ->
        duplicated_versions =
          duplicated
          |> Enum.uniq()
          |> Enum.sort()
          |> Enum.join(", ")

        raise("Typesense migration versions must be unique: #{duplicated_versions}")
    end
  end

  defp ensure_migrations_collection do
    schema = %{
      "name" => @migrations_collection,
      "fields" => [
        %{"name" => "version", "type" => "string"},
        %{"name" => "inserted_at", "type" => "int64"}
      ],
      "default_sorting_field" => "inserted_at"
    }

    Typesense.create_collection(schema)
    |> ensure_collection_created(@migrations_collection)
  end

  defp applied_migration_versions do
    load_applied_migration_versions(1, MapSet.new())
  end

  defp load_applied_migration_versions(page, acc) do
    case Typesense.list_documents!(@migrations_collection, @list_documents_page_size, page) do
      {:ok, docs} when is_list(docs) ->
        next_acc =
          docs
          |> Enum.reduce(acc, fn doc, set ->
            case Map.get(doc, "version") do
              version when is_binary(version) -> MapSet.put(set, version)
              _ -> set
            end
          end)

        if length(docs) < @list_documents_page_size do
          next_acc
        else
          load_applied_migration_versions(page + 1, next_acc)
        end

      {:ok, _other} ->
        acc

      {:error, "Not Found"} ->
        acc

      {:error, reason} ->
        raise("Typesense list migration versions failed: #{reason}")
    end
  end

  defp record_migration_version(version) do
    document = %{
      "id" => version,
      "version" => version,
      "inserted_at" => System.system_time(:second)
    }

    case Typesense.create_document(@migrations_collection, document) do
      {:ok, _} -> :ok
      {:error, "Conflict"} -> :ok
      {:error, reason} -> raise("Typesense record migration version failed: #{reason}")
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

  defp ensure_collection_fields(collection_name, fields, action) when is_list(fields) do
    existing_field_names = collection_field_names(collection_name)

    missing_fields =
      Enum.reject(fields, fn field ->
        field_name = Map.get(field, "name")
        MapSet.member?(existing_field_names, field_name)
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
        |> MapSet.new()

      _ ->
        MapSet.new()
    end
  end
end
