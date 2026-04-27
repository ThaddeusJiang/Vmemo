defmodule Vmemo.UserSettings do
  @moduledoc false
  require Ash.Query
  require Logger

  alias Vmemo.Account.User
  alias Vmemo.ImportExport.Errors
  alias Vmemo.ImportExport.Ids
  alias Vmemo.ImportExport.Json
  alias Vmemo.ImportExport.Zip
  alias Vmemo.Memo.Note
  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageNote
  alias Vmemo.Repo

  @error_limit 50

  def export_user_zip(user_id) when is_binary(user_id) do
    tmp_dir = build_tmp_dir("vmemo-user-export")

    result =
      with {:ok, user} <- fetch_user(user_id),
           {:ok, images} <- list_user_images(user_id),
           {:ok, notes} <- list_user_notes(user_id),
           {:ok, links} <- list_note_links(notes),
           :ok <- write_export_payload(tmp_dir, user, images, notes, links),
           files <- copy_user_storage_for_export(tmp_dir, user_id),
           {:ok, binary, filename} <- build_zip_binary(tmp_dir) do
        {:ok, %{binary: binary, filename: filename, files: files}}
      end

    File.rm_rf(tmp_dir)
    result
  end

  def import_user_zip(user_id, zip_path) when is_binary(user_id) and is_binary(zip_path) do
    tmp_dir = build_tmp_dir("vmemo-user-import")

    result =
      with :ok <- extract_zip(zip_path, tmp_dir),
           {:ok, payload} <- read_import_payload(tmp_dir),
           {:ok, import_result} <- import_payload_for_user(payload, tmp_dir, user_id) do
        {:ok, import_result}
      else
        {:error, %{} = result} -> {:error, result}
        {:error, reason} -> {:error, reason}
      end

    File.rm_rf(tmp_dir)
    result
  end

  defp fetch_user(user_id) do
    case Ash.get(User, user_id, actor: nil, authorize?: false) do
      {:ok, user} -> {:ok, user}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, "User not found"}
      {:error, error} -> {:error, format_error(error)}
    end
  end

  defp list_user_images(user_id) do
    query =
      Image
      |> Ash.Query.filter(user_id == ^user_id)
      |> Ash.Query.sort(inserted_at: :desc)

    case Ash.read(query, actor: nil, authorize?: false) do
      {:ok, images} -> {:ok, images}
      {:error, error} -> {:error, format_error(error)}
    end
  end

  defp list_user_notes(user_id) do
    query =
      Note
      |> Ash.Query.filter(user_id == ^user_id)
      |> Ash.Query.sort(inserted_at: :desc)

    case Ash.read(query, actor: nil, authorize?: false) do
      {:ok, notes} -> {:ok, notes}
      {:error, error} -> {:error, format_error(error)}
    end
  end

  defp list_note_links(notes) do
    note_ids = Enum.map(notes, & &1.id)

    if note_ids == [] do
      {:ok, %{}}
    else
      query =
        ImageNote
        |> Ash.Query.filter(note_id in ^note_ids)

      case Ash.read(query, actor: nil, authorize?: false) do
        {:ok, links} ->
          mapped =
            Enum.reduce(links, %{}, fn link, acc ->
              Map.update(acc, link.note_id, [link.image_id], fn ids -> [link.image_id | ids] end)
            end)

          {:ok, mapped}

        {:error, error} ->
          {:error, format_error(error)}
      end
    end
  end

  defp write_export_payload(tmp_dir, user, images, notes, links) do
    data_dir = Path.join(tmp_dir, "data")
    File.mkdir_p!(data_dir)

    metadata = %{
      format: "vmemo-user-export",
      version: 1,
      exported_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      user_id: user.id
    }

    user_data = %{
      id: user.id,
      email: user.email,
      inserted_at: to_iso8601(user.inserted_at),
      updated_at: to_iso8601(user.updated_at)
    }

    images_data =
      Enum.map(images, fn image ->
        %{
          id: image.id,
          url: image.url,
          note: image.note,
          caption: image.caption,
          file_id: image.file_id,
          user_id: image.user_id,
          _purpose: image.inner_purpose,
          inserted_at: to_iso8601(image.inserted_at),
          updated_at: to_iso8601(image.updated_at)
        }
      end)

    notes_data =
      Enum.map(notes, fn note ->
        %{
          id: note.id,
          text: note.text,
          user_id: note.user_id,
          image_ids: Map.get(links, note.id, []) |> Enum.uniq(),
          inserted_at: to_iso8601(note.inserted_at),
          updated_at: to_iso8601(note.updated_at)
        }
      end)

    typesense_images = build_typesense_image_docs(images, links, user.id)
    typesense_notes = build_typesense_note_docs(notes_data, user.id)

    [
      {"metadata.json", metadata},
      {"user.json", user_data},
      {"images.json", images_data},
      {"notes.json", notes_data},
      {"typesense_images.json", typesense_images},
      {"typesense_notes.json", typesense_notes}
    ]
    |> Enum.reduce_while(:ok, fn {filename, payload}, :ok ->
      case write_json(Path.join(data_dir, filename), payload) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp copy_user_storage_for_export(tmp_dir, user_id) do
    source_root = Path.join(["storage", "v1", user_id, "images"])
    dest_root = Path.join([tmp_dir, "storage", "v1", user_id, "images"])

    if File.exists?(source_root) do
      files =
        source_root
        |> Path.join("**/*")
        |> Path.wildcard()
        |> Enum.filter(&File.regular?/1)

      Enum.reduce(files, %{copied: 0, skipped: 0}, fn source, acc ->
        rel_path = Path.relative_to(source, source_root)
        dest = Path.join(dest_root, rel_path)
        File.mkdir_p!(Path.dirname(dest))

        if File.exists?(dest) do
          %{acc | skipped: acc.skipped + 1}
        else
          File.cp!(source, dest)
          %{acc | copied: acc.copied + 1}
        end
      end)
    else
      %{copied: 0, skipped: 0}
    end
  end

  defp build_zip_binary(tmp_dir) do
    filename = "vmemo-data-#{date_part()}.zip"
    zip_path = Path.join(System.tmp_dir!(), filename)

    case zip_dir(tmp_dir, zip_path) do
      :ok ->
        case File.read(zip_path) do
          {:ok, binary} ->
            File.rm(zip_path)
            {:ok, binary, filename}

          {:error, reason} ->
            File.rm(zip_path)
            {:error, "Failed to read export zip: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp import_payload_for_user(payload, tmp_dir, user_id) do
    source_user_id = source_user_id_from_payload(payload, tmp_dir)

    file_stats = copy_user_storage_for_import(tmp_dir, source_user_id, user_id)

    {image_stats, image_id_map, image_ids, image_errors} =
      import_images(payload.images, source_user_id, user_id)

    {note_stats, note_id_map, note_photo_map, note_ids, note_errors} =
      import_notes(payload.notes, user_id)

    {link_stats, link_errors} =
      import_photo_links(note_photo_map, image_id_map, note_id_map, image_ids, note_ids)

    {typesense_stats, typesense_errors} = sync_imported_typesense_documents(image_ids, note_ids)

    errors =
      []
      |> append_errors(image_errors)
      |> append_errors(note_errors)
      |> append_errors(link_errors)
      |> append_errors(typesense_errors)

    result = %{
      metadata: payload.metadata,
      files: file_stats,
      images: image_stats,
      notes: note_stats,
      image_notes: link_stats,
      typesense: typesense_stats,
      errors: errors,
      error_count: length(errors)
    }

    if errors == [] do
      {:ok, result}
    else
      {:error, result}
    end
  end

  defp import_images(images, source_user_id, target_user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    {prepared, errors} =
      prepare_import_images(images, source_user_id, target_user_id, now)

    prepared = Enum.reverse(prepared)

    valid_uuid_ids =
      prepared |> Enum.map(&extract_valid_uuid_id(&1.raw_id)) |> Enum.reject(&is_nil/1)

    existing_owner_map = fetch_existing_owner_map("memo_images", valid_uuid_ids)

    generated_ids =
      prepared
      |> Enum.count(&image_row_needs_generated_id?(&1, existing_owner_map))
      |> generate_uuid_v7_list()

    {rows_to_insert, id_map, ids, skipped_from_existing, _generated_tail} =
      build_image_insert_rows(prepared, existing_owner_map, generated_ids)

    rows_to_insert = Enum.reverse(rows_to_insert)

    {inserted_count, insert_errors} = insert_rows("memo_images", rows_to_insert)

    created = inserted_count
    skipped = skipped_from_existing + max(length(rows_to_insert) - inserted_count, 0)
    failed = length(insert_errors)
    errors = append_errors(errors, insert_errors)

    {%{created: created, skipped: skipped, failed: failed}, id_map, ids, errors}
  end

  defp prepare_import_images(images, source_user_id, target_user_id, now) do
    Enum.reduce(images, {[], []}, fn image, {rows, errs} ->
      case build_prepared_image_row(image, source_user_id, target_user_id, now) do
        {:ok, row} -> {[row | rows], errs}
        {:error, message} -> {rows, add_error(errs, message)}
      end
    end)
  end

  defp build_prepared_image_row(image, source_user_id, target_user_id, now) do
    legacy_id = pick_value(image, ["id", :id])
    raw_url = pick_value(image, ["url", :url])
    url = remap_image_url(raw_url, source_user_id, target_user_id)

    cond do
      is_nil(legacy_id) or is_nil(url) ->
        {:error, "Image missing id or url"}

      storage_url?(url) and not file_exists_for_storage_url?(url) ->
        {:error, "Image file missing for #{inspect(legacy_id)}: #{url}"}

      true ->
        {:ok,
         %{
           legacy_id: legacy_id,
           raw_id: legacy_id,
           url: url,
           note: pick_value(image, ["note", :note]),
           caption: pick_value(image, ["caption", :caption]),
           file_id: pick_value(image, ["file_id", :file_id]),
           user_id: target_user_id,
           _purpose: normalize_import_purpose(image),
           inserted_at: parse_iso_datetime(pick_value(image, ["inserted_at", :inserted_at]), now),
           updated_at: parse_iso_datetime(pick_value(image, ["updated_at", :updated_at]), now)
         }}
    end
  end

  defp image_row_needs_generated_id?(row, existing_owner_map) do
    case extract_valid_uuid_id(row.raw_id) do
      nil -> true
      valid_id -> Map.get(existing_owner_map, valid_id) not in [nil, row.user_id]
    end
  end

  defp build_image_insert_rows(prepared, existing_owner_map, generated_ids) do
    Enum.reduce(prepared, {[], %{}, MapSet.new(), 0, generated_ids}, fn row, acc ->
      assign_image_row_id(row, acc, existing_owner_map)
    end)
  end

  defp assign_image_row_id(row, {insert_rows, map, id_set, skipped, gen_ids}, existing_owner_map) do
    case resolve_image_id_for_row(row, existing_owner_map, gen_ids) do
      {:insert, assigned_id, next_gen_ids} ->
        db_row =
          row
          |> Map.drop([:legacy_id, :raw_id])
          |> Map.put(:id, uuid_to_db(assigned_id))
          |> Map.update!(:user_id, &uuid_to_db/1)

        {[db_row | insert_rows], Map.put(map, row.legacy_id, assigned_id),
         MapSet.put(id_set, assigned_id), skipped, next_gen_ids}

      {:skip, assigned_id, next_gen_ids} ->
        {insert_rows, Map.put(map, row.legacy_id, assigned_id), MapSet.put(id_set, assigned_id),
         skipped + 1, next_gen_ids}
    end
  end

  defp resolve_image_id_for_row(row, existing_owner_map, gen_ids) do
    case extract_valid_uuid_id(row.raw_id) do
      valid_id when is_binary(valid_id) ->
        case Map.get(existing_owner_map, valid_id) do
          nil -> {:insert, valid_id, gen_ids}
          owner_id when owner_id == row.user_id -> {:skip, valid_id, gen_ids}
          _other_owner -> assign_new_image_id(gen_ids)
        end

      _ ->
        assign_new_image_id(gen_ids)
    end
  end

  defp assign_new_image_id([new_id | tail]), do: {:insert, new_id, tail}
  defp assign_new_image_id([]), do: {:insert, Ecto.UUID.generate(), []}

  defp insert_rows(_table, []), do: {0, []}

  defp insert_rows(table, rows) do
    {count, _} = Repo.insert_all(table, rows, on_conflict: :nothing, conflict_target: [:id])
    {count, []}
  end

  defp import_notes(notes, target_user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    {prepared, errors} =
      Enum.reduce(notes, {[], []}, fn note, {rows, errs} ->
        legacy_id = pick_value(note, ["id", :id])
        text = pick_value(note, ["text", :text]) || ""

        image_ids =
          note |> pick_value(["image_ids", :image_ids]) |> normalize_list() |> Enum.uniq()

        if is_nil(legacy_id) do
          {rows, add_error(errs, "Note missing id")}
        else
          row = %{
            legacy_id: legacy_id,
            raw_id: legacy_id,
            text: text,
            user_id: target_user_id,
            image_ids: image_ids,
            inserted_at: parse_iso_datetime(pick_value(note, ["inserted_at", :inserted_at]), now),
            updated_at: parse_iso_datetime(pick_value(note, ["updated_at", :updated_at]), now)
          }

          {[row | rows], errs}
        end
      end)

    prepared = Enum.reverse(prepared)

    valid_uuid_ids =
      prepared |> Enum.map(&extract_valid_uuid_id(&1.raw_id)) |> Enum.reject(&is_nil/1)

    existing_owner_map = fetch_existing_owner_map("memo_notes", valid_uuid_ids)

    generated_ids =
      prepared
      |> Enum.count(fn row ->
        case extract_valid_uuid_id(row.raw_id) do
          nil ->
            true

          valid_id ->
            case Map.get(existing_owner_map, valid_id) do
              nil -> false
              owner_id -> owner_id != row.user_id
            end
        end
      end)
      |> generate_uuid_v7_list()

    {rows_to_insert, id_map, note_photo_map, ids, skipped_from_existing, _generated_tail} =
      Enum.reduce(prepared, {[], %{}, %{}, MapSet.new(), 0, generated_ids}, fn row,
                                                                               {insert_rows, map,
                                                                                note_map, id_set,
                                                                                skipped, gen_ids} ->
        case extract_valid_uuid_id(row.raw_id) do
          valid_id when is_binary(valid_id) ->
            case Map.get(existing_owner_map, valid_id) do
              nil ->
                db_row =
                  row
                  |> Map.drop([:legacy_id, :raw_id, :image_ids])
                  |> Map.put(:id, uuid_to_db(valid_id))
                  |> Map.update!(:user_id, &uuid_to_db/1)

                {[db_row | insert_rows], Map.put(map, row.legacy_id, valid_id),
                 Map.put(note_map, row.legacy_id, row.image_ids), MapSet.put(id_set, valid_id),
                 skipped, gen_ids}

              owner_id when owner_id == row.user_id ->
                {insert_rows, Map.put(map, row.legacy_id, valid_id),
                 Map.put(note_map, row.legacy_id, row.image_ids), MapSet.put(id_set, valid_id),
                 skipped + 1, gen_ids}

              _other_owner ->
                [new_id | tail] = gen_ids

                db_row =
                  row
                  |> Map.drop([:legacy_id, :raw_id, :image_ids])
                  |> Map.put(:id, uuid_to_db(new_id))
                  |> Map.update!(:user_id, &uuid_to_db/1)

                {[db_row | insert_rows], Map.put(map, row.legacy_id, new_id),
                 Map.put(note_map, row.legacy_id, row.image_ids), MapSet.put(id_set, new_id),
                 skipped, tail}
            end

          _ ->
            [new_id | tail] = gen_ids

            db_row =
              row
              |> Map.drop([:legacy_id, :raw_id, :image_ids])
              |> Map.put(:id, uuid_to_db(new_id))
              |> Map.update!(:user_id, &uuid_to_db/1)

            {[db_row | insert_rows], Map.put(map, row.legacy_id, new_id),
             Map.put(note_map, row.legacy_id, row.image_ids), MapSet.put(id_set, new_id), skipped,
             tail}
        end
      end)

    rows_to_insert = Enum.reverse(rows_to_insert)

    {inserted_count, insert_errors} =
      case rows_to_insert do
        [] ->
          {0, []}

        rows ->
          {count, _} =
            Repo.insert_all("memo_notes", rows, on_conflict: :nothing, conflict_target: [:id])

          {count, []}
      end

    created = inserted_count
    skipped = skipped_from_existing + max(length(rows_to_insert) - inserted_count, 0)
    failed = length(insert_errors)
    errors = append_errors(errors, insert_errors)

    {%{created: created, skipped: skipped, failed: failed}, id_map, note_photo_map, ids, errors}
  end

  defp import_photo_links(note_photo_map, image_id_map, note_id_map, image_ids, note_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    pairs = build_photo_note_pairs(note_photo_map, image_id_map, note_id_map, image_ids, note_ids)

    pair_list = MapSet.to_list(pairs)
    existing_pairs = fetch_existing_photo_note_pairs(pair_list)
    to_insert_pairs = Enum.reject(pair_list, &Enum.member?(existing_pairs, &1))
    generated_ids = generate_uuid_v7_list(length(to_insert_pairs))

    rows_to_insert =
      Enum.zip(to_insert_pairs, generated_ids)
      |> Enum.map(fn {{image_id, note_id}, id} ->
        %{
          id: uuid_to_db(id),
          image_id: uuid_to_db(image_id),
          note_id: uuid_to_db(note_id),
          inserted_at: now
        }
      end)

    {inserted_count, insert_errors} =
      case rows_to_insert do
        [] ->
          {0, []}

        rows ->
          {count, _} =
            Repo.insert_all("memo_images_notes", rows,
              on_conflict: :nothing,
              conflict_target: [:image_id, :note_id]
            )

          {count, []}
      end

    skipped =
      length(existing_pairs) + max(length(rows_to_insert) - inserted_count, 0)

    {%{created: inserted_count, skipped: skipped, failed: length(insert_errors)}, insert_errors}
  end

  defp build_photo_note_pairs(note_photo_map, image_id_map, note_id_map, image_ids, note_ids) do
    Enum.reduce(note_photo_map, MapSet.new(), fn pair, acc ->
      append_photo_note_pairs(pair, acc, image_id_map, note_id_map, image_ids, note_ids)
    end)
  end

  defp append_photo_note_pairs(
         {legacy_note_id, legacy_image_ids},
         acc,
         image_id_map,
         note_id_map,
         image_ids,
         note_ids
       ) do
    note_id = Map.get(note_id_map, legacy_note_id)

    Enum.reduce(legacy_image_ids, acc, fn legacy_image_id, inner ->
      image_id = Map.get(image_id_map, legacy_image_id)

      if valid_photo_note_pair?(image_id, note_id, image_ids, note_ids) do
        MapSet.put(inner, {image_id, note_id})
      else
        inner
      end
    end)
  end

  defp valid_photo_note_pair?(image_id, note_id, image_ids, note_ids) do
    not is_nil(note_id) and
      not is_nil(image_id) and
      MapSet.member?(note_ids, note_id) and
      MapSet.member?(image_ids, image_id)
  end

  defp sync_imported_typesense_documents(image_ids, note_ids) do
    {image_stats, image_errors} =
      sync_typesense_records(
        MapSet.to_list(image_ids),
        fn id -> Image.sync_typesense_by_id(id, actor: nil, authorize?: false) end,
        "image"
      )

    {note_stats, note_errors} =
      sync_typesense_records(
        MapSet.to_list(note_ids),
        fn id -> Note.sync_typesense_by_id(id, actor: nil, authorize?: false) end,
        "note"
      )

    {%{images: image_stats, notes: note_stats}, image_errors ++ note_errors}
  end

  defp sync_typesense_records([], _sync_fun, _entity_name) do
    {%{requested: 0, success: 0, failed: 0}, []}
  end

  defp sync_typesense_records(ids, sync_fun, entity_name) do
    chunk_size = typesense_import_chunk_size()
    chunk_pause_ms = typesense_import_chunk_pause_ms()

    ids
    |> Enum.chunk_every(chunk_size)
    |> Enum.with_index()
    |> Enum.reduce(
      {%{requested: 0, success: 0, failed: 0}, []},
      fn {chunk, idx}, {stats, errors} ->
        if idx > 0 and chunk_pause_ms > 0 do
          Process.sleep(chunk_pause_ms)
        end

        {chunk_stats, chunk_errors} =
          Enum.reduce(chunk, {%{requested: 0, success: 0, failed: 0}, []}, fn id,
                                                                              {chunk_stats_acc,
                                                                               chunk_errors_acc} ->
            requested = chunk_stats_acc.requested + 1

            case safe_sync_call(sync_fun, id) do
              {:ok, true} ->
                {%{chunk_stats_acc | requested: requested, success: chunk_stats_acc.success + 1},
                 chunk_errors_acc}

              {:ok, false} ->
                {%{chunk_stats_acc | requested: requested, failed: chunk_stats_acc.failed + 1},
                 add_error(chunk_errors_acc, "Typesense #{entity_name} sync failed for #{id}")}

              {:error, reason} ->
                {%{chunk_stats_acc | requested: requested, failed: chunk_stats_acc.failed + 1},
                 add_error(
                   chunk_errors_acc,
                   "Typesense #{entity_name} sync failed for #{id}: #{format_error(reason)}"
                 )}

              other ->
                {%{chunk_stats_acc | requested: requested, failed: chunk_stats_acc.failed + 1},
                 add_error(
                   chunk_errors_acc,
                   "Typesense #{entity_name} sync returned unexpected result for #{id}: #{inspect(other)}"
                 )}
            end
          end)

        merged_stats = %{
          requested: stats.requested + chunk_stats.requested,
          success: stats.success + chunk_stats.success,
          failed: stats.failed + chunk_stats.failed
        }

        {merged_stats, errors ++ chunk_errors}
      end
    )
  end

  defp safe_sync_call(sync_fun, id) do
    sync_fun.(id)
  rescue
    exception ->
      {:error, Exception.message(exception)}
  catch
    kind, reason ->
      {:error, "#{kind}: #{inspect(reason)}"}
  end

  defp source_user_id_from_payload(payload, tmp_dir) do
    payload.metadata["user_id"] ||
      payload.metadata[:user_id] ||
      payload.user["id"] ||
      payload.user[:id] ||
      typesense_source_user_id(payload) ||
      detect_storage_user_id(tmp_dir)
  end

  defp typesense_source_user_id(payload) do
    first_photo =
      payload
      |> pick_value([:typesense_images, "typesense_images"])
      |> normalize_list()
      |> List.first()

    first_note =
      payload
      |> pick_value([:typesense_notes, "typesense_notes"])
      |> normalize_list()
      |> List.first()

    pick_value(first_photo, ["inserted_by", :inserted_by]) ||
      pick_value(first_note, ["belongs_to", :belongs_to])
  end

  defp detect_storage_user_id(tmp_dir) do
    root = Path.join([tmp_dir, "storage", "v1"])

    if File.exists?(root) do
      root
      |> File.ls!()
      |> Enum.find(fn entry ->
        Path.join(root, entry) |> File.dir?()
      end)
    else
      nil
    end
  end

  defp copy_user_storage_for_import(tmp_dir, source_user_id, target_user_id) do
    source_root = Path.join([tmp_dir, "storage", "v1", to_string(source_user_id || ""), "images"])
    target_root = Path.join(["storage", "v1", target_user_id, "images"])

    if source_user_id && File.exists?(source_root) do
      files =
        source_root
        |> Path.join("**/*")
        |> Path.wildcard()
        |> Enum.filter(&File.regular?/1)

      Enum.reduce(files, %{copied: 0, skipped: 0}, fn source, acc ->
        rel_path = Path.relative_to(source, source_root)
        dest = Path.join(target_root, rel_path)
        File.mkdir_p!(Path.dirname(dest))

        if File.exists?(dest) do
          %{acc | skipped: acc.skipped + 1}
        else
          File.cp!(source, dest)
          %{acc | copied: acc.copied + 1}
        end
      end)
    else
      %{copied: 0, skipped: 0}
    end
  end

  defp remap_image_url(nil, _source_user_id, _target_user_id), do: nil

  defp remap_image_url(url, source_user_id, target_user_id) do
    source_prefix =
      case source_user_id do
        nil -> nil
        id -> "/storage/v1/#{id}/images/"
      end

    target_prefix = "/storage/v1/#{target_user_id}/images/"

    cond do
      is_binary(source_prefix) and String.starts_with?(url, source_prefix) ->
        String.replace_prefix(url, source_prefix, target_prefix)

      String.starts_with?(url, "/storage/v1/") ->
        filename = Path.basename(url)
        target_prefix <> filename

      true ->
        url
    end
  end

  defp read_import_payload(tmp_dir) do
    data_dir = Path.join(tmp_dir, "data")

    case read_json(Path.join(data_dir, "metadata.json")) do
      {:ok, metadata} ->
        {:ok,
         %{
           metadata: metadata,
           user: read_optional_json(Path.join(data_dir, "user.json")) || %{},
           images: normalize_list(read_optional_json(Path.join(data_dir, "images.json"))),
           notes: normalize_list(read_optional_json(Path.join(data_dir, "notes.json"))),
           typesense_images:
             normalize_list(read_optional_json(Path.join(data_dir, "typesense_images.json"))),
           typesense_notes:
             normalize_list(read_optional_json(Path.join(data_dir, "typesense_notes.json")))
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_zip(zip_path, tmp_dir) do
    Zip.extract_zip(zip_path, tmp_dir)
  end

  defp write_json(path, data) do
    Json.write_json(path, data)
  end

  defp read_json(path) do
    Json.read_json(path)
  end

  defp read_optional_json(path) do
    Json.read_optional_json(path)
  end

  defp zip_dir(source_dir, target_zip_path) do
    Zip.zip_dir(source_dir, target_zip_path)
  end

  defp build_typesense_image_docs(images, links, user_id) do
    image_to_note_ids = invert_note_image_links(links)

    Enum.reduce(images, [], fn image_row, acc ->
      case read_image_base64(image_row.url) do
        {:ok, image_base64} ->
          inserted_at = datetime_to_unix(image_row.inserted_at)

          doc =
            %{
              "id" => image_row.id,
              "image" => image_base64,
              "note" => image_row.note || "",
              "caption" => image_row.caption || "",
              "note_ids" => Map.get(image_to_note_ids, image_row.id, []),
              "url" => image_row.url,
              "file_id" => image_row.file_id,
              "inserted_at" => inserted_at,
              "inserted_by" => user_id
            }
            |> maybe_put_typesense_purpose(image_row.inner_purpose)

          [doc | acc]

        {:error, reason} ->
          Logger.warning("Skip typesense image export for #{image_row.id}: #{inspect(reason)}")
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp build_typesense_note_docs(notes_data, user_id) do
    Enum.map(notes_data, fn note ->
      %{
        "id" => pick_value(note, ["id", :id]),
        "text" => pick_value(note, ["text", :text]) || "",
        "image_ids" => pick_value(note, ["image_ids", :image_ids]) |> normalize_list(),
        "inserted_at" => iso8601_to_unix(pick_value(note, ["inserted_at", :inserted_at])),
        "updated_at" => iso8601_to_unix(pick_value(note, ["updated_at", :updated_at])),
        "belongs_to" => user_id
      }
    end)
  end

  defp invert_note_image_links(links) do
    Enum.reduce(links, %{}, fn {note_id, image_ids}, acc ->
      Enum.reduce(image_ids, acc, fn image_id, inner ->
        Map.update(inner, image_id, [note_id], fn ids -> [note_id | ids] end)
      end)
    end)
    |> Enum.into(%{}, fn {image_id, note_ids} ->
      {image_id, note_ids |> Enum.uniq() |> Enum.reverse()}
    end)
  end

  defp read_image_base64(url) when is_binary(url) do
    case url_to_storage_path(url) do
      nil ->
        {:error, :invalid_path}

      path ->
        case File.read(path) do
          {:ok, binary} -> {:ok, Base.encode64(binary)}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp read_image_base64(_url), do: {:error, :invalid_url}

  defp url_to_storage_path(url) do
    path =
      case URI.parse(url) do
        %URI{path: nil} -> url
        %URI{path: parsed_path} -> parsed_path
      end

    cond do
      String.starts_with?(path, "/storage/v1/") ->
        path
        |> String.trim_leading("/")
        |> Path.expand(File.cwd!())

      String.starts_with?(path, "storage/v1/") ->
        Path.expand(path, File.cwd!())

      true ->
        nil
    end
  end

  defp datetime_to_unix(%DateTime{} = dt), do: DateTime.to_unix(dt)

  defp datetime_to_unix(%NaiveDateTime{} = dt),
    do: DateTime.from_naive!(dt, "Etc/UTC") |> DateTime.to_unix()

  defp datetime_to_unix(_), do: DateTime.utc_now() |> DateTime.to_unix()

  defp iso8601_to_unix(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> DateTime.to_unix(dt)
      _ -> DateTime.utc_now() |> DateTime.to_unix()
    end
  end

  defp iso8601_to_unix(_), do: DateTime.utc_now() |> DateTime.to_unix()

  defp normalize_record_id(id) when is_binary(id) do
    cond do
      Ids.valid_uuid?(id) -> {:uuid, id}
      String.match?(id, ~r/^\d+$/) -> {:legacy, id}
      true -> :invalid
    end
  end

  defp normalize_record_id(id) when is_integer(id), do: Ids.normalize_record_id(id)
  defp normalize_record_id(_id), do: Ids.normalize_record_id(nil)

  defp normalize_list(value), do: Json.normalize_list(value)

  defp normalize_import_purpose(image) when is_map(image) do
    case pick_value(image, [
           "_purpose",
           :_purpose,
           "inner_purpose",
           :inner_purpose,
           "image_purpose",
           :image_purpose
         ]) do
      nil -> nil
      "" -> nil
      "library" -> nil
      "similarity_query" -> "search"
      other when is_binary(other) -> other
      _ -> nil
    end
  end

  defp maybe_put_typesense_purpose(doc, value) when is_binary(value),
    do: Map.put(doc, "_purpose", value)

  defp maybe_put_typesense_purpose(doc, _), do: doc

  defp pick_value(map, keys) when is_map(map) do
    Enum.find_value(keys, fn key ->
      case key do
        atom when is_atom(atom) -> Map.get(map, atom)
        string when is_binary(string) -> Map.get(map, string)
      end
    end)
  end

  defp pick_value(_map, _keys), do: nil

  defp typesense_import_chunk_size do
    Application.get_env(:vmemo, :user_data_import_typesense_chunk_size, 50)
  end

  defp typesense_import_chunk_pause_ms do
    Application.get_env(:vmemo, :user_data_import_typesense_chunk_pause_ms, 50)
  end

  defp extract_valid_uuid_id(value) do
    case normalize_record_id(value) do
      {:uuid, uuid} -> uuid
      _ -> nil
    end
  end

  defp generate_uuid_v7_list(0), do: []

  defp generate_uuid_v7_list(count) when count > 0 do
    query = "SELECT uuid_generate_v7()::text FROM generate_series(1, $1)"

    case Repo.query(query, [count]) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [id] -> id end)
      _ -> Enum.map(1..count, fn _ -> Ecto.UUID.generate() end)
    end
  end

  defp fetch_existing_owner_map(_table, []), do: %{}

  defp fetch_existing_owner_map(table, ids) when table in ["memo_images", "memo_notes"] do
    query = "SELECT id::text, user_id::text FROM #{table} WHERE id::text = ANY($1::text[])"

    case Repo.query(query, [ids]) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [id, owner_id] -> {id, owner_id} end)

      _ ->
        %{}
    end
  end

  defp fetch_existing_photo_note_pairs([]), do: []

  defp fetch_existing_photo_note_pairs(pairs) do
    {image_ids, note_ids} = Enum.unzip(pairs)
    image_ids = Enum.uniq(image_ids)
    note_ids = Enum.uniq(note_ids)

    query = """
    SELECT image_id::text, note_id::text
    FROM memo_images_notes
    WHERE image_id::text = ANY($1::text[]) AND note_id::text = ANY($2::text[])
    """

    case Repo.query(query, [image_ids, note_ids]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [image_id, note_id] -> {image_id, note_id} end)

      _ ->
        []
    end
  end

  defp parse_iso_datetime(nil, default), do: default

  defp parse_iso_datetime(value, default) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> DateTime.truncate(dt, :microsecond)
      _ -> default
    end
  end

  defp parse_iso_datetime(%DateTime{} = value, _default),
    do: DateTime.truncate(value, :microsecond)

  defp parse_iso_datetime(%NaiveDateTime{} = value, _default),
    do: DateTime.from_naive!(value, "Etc/UTC")

  defp parse_iso_datetime(_value, default), do: default

  defp storage_url?(url) when is_binary(url) do
    path =
      case URI.parse(url) do
        %URI{path: parsed_path} when is_binary(parsed_path) -> parsed_path
        _ -> url
      end

    String.starts_with?(path, "/storage/v1/") or String.starts_with?(path, "storage/v1/")
  end

  defp storage_url?(_url), do: false

  defp file_exists_for_storage_url?(url) do
    case url_to_storage_path(url) do
      nil -> false
      path -> File.exists?(path)
    end
  end

  defp uuid_to_db(value) when is_binary(value) do
    case Ecto.UUID.dump(value) do
      {:ok, dumped} -> dumped
      :error -> value
    end
  end

  defp uuid_to_db(value), do: value

  defp build_tmp_dir(prefix) do
    base = System.tmp_dir!()
    tmp_dir = Path.join(base, "#{prefix}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    tmp_dir
  end

  defp date_part do
    Date.utc_today()
    |> Date.to_iso8601()
    |> String.replace(~r/[^0-9]/, "")
  end

  defp to_iso8601(nil), do: nil
  defp to_iso8601(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp to_iso8601(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp to_iso8601(value), do: value

  defp append_errors(errors, more) do
    Errors.append_errors(errors, more)
    |> Enum.take(@error_limit)
  end

  defp add_error(errors, error), do: Errors.add_error(errors, error, @error_limit)

  defp format_error(error), do: Errors.format_error(error)
end
