defmodule Vmemo.Ts.Schema do
  @moduledoc false

  alias SmallSdk.Typesense

  def reset do
    migrations_collection =
      [Vmemo, Ts, SchemaMigrator]
      |> Module.concat()
      |> apply(:migrations_collection, [])

    Typesense.drop_collection("memo_images")
    |> ensure_ok("drop memo_images collection")

    Typesense.drop_collection("memo_notes")
    |> ensure_ok("drop memo_notes collection")

    # Legacy collection names for backward compatibility during rename.
    Typesense.drop_collection("images")
    |> ensure_ok("drop legacy images collection")

    Typesense.drop_collection("photos")
    |> ensure_ok("drop legacy photos collection")

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
    load_applied_migration_versions(migrations_collection, 1, 100, MapSet.new())
  end

  defp load_applied_migration_versions(migrations_collection, page, per_page, acc) do
    params = [q: "*", query_by: "version", per_page: per_page, page: page]

    case Typesense.search_documents(migrations_collection, params) do
      {:ok, %{documents: docs, found: found}} when is_list(docs) and is_integer(found) ->
        next_acc = Enum.reduce(docs, acc, &put_migration_version/2)
        maybe_load_next_migration_page(migrations_collection, page, per_page, found, next_acc)

      {:ok, _other} ->
        acc

      {:error, "Not Found"} ->
        acc

      {:error, reason} ->
        raise("Typesense search migration versions failed: #{reason}")
    end
  end

  defp put_migration_version(doc, set) do
    case Map.get(doc, "version") do
      version when is_binary(version) -> MapSet.put(set, version)
      _ -> set
    end
  end

  defp maybe_load_next_migration_page(migrations_collection, page, per_page, found, acc) do
    if page * per_page >= found do
      acc
    else
      load_applied_migration_versions(migrations_collection, page + 1, per_page, acc)
    end
  end

  defp ensure_collection_created({:ok, _}, _collection), do: :ok
  defp ensure_collection_created({:error, "Conflict"}, _collection), do: :ok

  defp ensure_collection_created(result, collection),
    do: ensure_ok(result, "create #{collection} collection")

  defp ensure_ok({:ok, _}, _action), do: :ok
  defp ensure_ok({:error, "Not Found"}, _action), do: :ok
  defp ensure_ok({:error, reason}, action), do: raise("Typesense #{action} failed: #{reason}")
end
