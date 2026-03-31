defmodule Vmemo.UserDataTransfer do
  require Ash.Query
  require Logger

  alias Vmemo.Repo
  alias Vmemo.Account.AshUser
  alias Vmemo.Photos.Note
  alias Vmemo.Photos.Photo
  alias Vmemo.Photos.PhotoNote

  @error_limit 50

  def export_user_zip(user_id) when is_binary(user_id) do
    tmp_dir = build_tmp_dir("vmemo-user-export")

    result =
      with {:ok, user} <- fetch_user(user_id),
           {:ok, photos} <- list_user_photos(user_id),
           {:ok, notes} <- list_user_notes(user_id),
           {:ok, links} <- list_note_links(notes),
           :ok <- write_export_payload(tmp_dir, user, photos, notes, links),
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
    case Ash.get(AshUser, user_id, actor: nil, authorize?: false) do
      {:ok, user} -> {:ok, user}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, "User not found"}
      {:error, error} -> {:error, format_error(error)}
    end
  end

  defp list_user_photos(user_id) do
    query =
      Photo
      |> Ash.Query.filter(ash_user_id == ^user_id)
      |> Ash.Query.sort(inserted_at: :desc)

    case Ash.read(query, actor: nil, authorize?: false) do
      {:ok, photos} -> {:ok, photos}
      {:error, error} -> {:error, format_error(error)}
    end
  end

  defp list_user_notes(user_id) do
    query =
      Note
      |> Ash.Query.filter(ash_user_id == ^user_id)
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
        PhotoNote
        |> Ash.Query.filter(note_id in ^note_ids)

      case Ash.read(query, actor: nil, authorize?: false) do
        {:ok, links} ->
          mapped =
            Enum.reduce(links, %{}, fn link, acc ->
              Map.update(acc, link.note_id, [link.photo_id], fn ids -> [link.photo_id | ids] end)
            end)

          {:ok, mapped}

        {:error, error} ->
          {:error, format_error(error)}
      end
    end
  end

  defp write_export_payload(tmp_dir, user, photos, notes, links) do
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

    photos_data =
      Enum.map(photos, fn photo ->
        %{
          id: photo.id,
          url: photo.url,
          note: photo.note,
          caption: photo.caption,
          ts_ocr: Map.get(photo, :ts_ocr),
          file_id: photo.file_id,
          ash_user_id: photo.ash_user_id,
          inserted_at: to_iso8601(photo.inserted_at),
          updated_at: to_iso8601(photo.updated_at)
        }
      end)

    notes_data =
      Enum.map(notes, fn note ->
        %{
          id: note.id,
          text: note.text,
          ash_user_id: note.ash_user_id,
          photo_ids: Map.get(links, note.id, []) |> Enum.uniq(),
          inserted_at: to_iso8601(note.inserted_at),
          updated_at: to_iso8601(note.updated_at)
        }
      end)

    typesense_photos = build_typesense_photo_docs(photos, links, user.id)
    typesense_notes = build_typesense_note_docs(notes_data, user.id)

    with :ok <- write_json(Path.join(data_dir, "metadata.json"), metadata),
         :ok <- write_json(Path.join(data_dir, "user.json"), user_data),
         :ok <- write_json(Path.join(data_dir, "photos.json"), photos_data),
         :ok <- write_json(Path.join(data_dir, "notes.json"), notes_data),
         :ok <- write_json(Path.join(data_dir, "typesense_photos.json"), typesense_photos),
         :ok <- write_json(Path.join(data_dir, "typesense_notes.json"), typesense_notes) do
      :ok
    end
  end

  defp copy_user_storage_for_export(tmp_dir, user_id) do
    source_root = Path.join(["storage", "v1", user_id, "photos"])
    dest_root = Path.join([tmp_dir, "storage", "v1", user_id, "photos"])

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

    {photo_stats, photo_id_map, photo_ids, photo_errors} =
      import_photos(payload.photos, source_user_id, user_id)

    {note_stats, note_id_map, note_photo_map, note_ids, note_errors} =
      import_notes(payload.notes, user_id)

    {link_stats, link_errors} =
      import_photo_links(note_photo_map, photo_id_map, note_id_map, photo_ids, note_ids)

    {typesense_stats, typesense_errors} = sync_imported_typesense_documents(photo_ids, note_ids)

    errors =
      []
      |> append_errors(photo_errors)
      |> append_errors(note_errors)
      |> append_errors(link_errors)
      |> append_errors(typesense_errors)

    result = %{
      metadata: payload.metadata,
      files: file_stats,
      photos: photo_stats,
      notes: note_stats,
      photo_notes: link_stats,
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

  defp import_photos(photos, source_user_id, target_user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    {prepared, errors} =
      Enum.reduce(photos, {[], []}, fn photo, {rows, errs} ->
        legacy_id = pick_value(photo, ["id", :id])
        raw_url = pick_value(photo, ["url", :url])
        url = remap_photo_url(raw_url, source_user_id, target_user_id)

        cond do
          is_nil(legacy_id) or is_nil(url) ->
            {rows, add_error(errs, "Photo missing id or url")}

          storage_url?(url) and not file_exists_for_storage_url?(url) ->
            {rows, add_error(errs, "Photo file missing for #{inspect(legacy_id)}: #{url}")}

          true ->
            row = %{
              legacy_id: legacy_id,
              raw_id: legacy_id,
              url: url,
              note: pick_value(photo, ["note", :note]),
              caption: pick_value(photo, ["caption", :caption]),
              ts_ocr: pick_value(photo, ["ts_ocr", :ts_ocr]),
              file_id: pick_value(photo, ["file_id", :file_id]),
              ash_user_id: target_user_id,
              inserted_at:
                parse_iso_datetime(pick_value(photo, ["inserted_at", :inserted_at]), now),
              updated_at: parse_iso_datetime(pick_value(photo, ["updated_at", :updated_at]), now)
            }

            {[row | rows], errs}
        end
      end)

    prepared = Enum.reverse(prepared)

    valid_uuid_ids =
      prepared |> Enum.map(&extract_valid_uuid_id(&1.raw_id)) |> Enum.reject(&is_nil/1)

    existing_owner_map = fetch_existing_owner_map("photos", valid_uuid_ids)

    generated_ids =
      prepared
      |> Enum.count(fn row ->
        case extract_valid_uuid_id(row.raw_id) do
          nil ->
            true

          valid_id ->
            case Map.get(existing_owner_map, valid_id) do
              nil -> false
              owner_id -> owner_id != row.ash_user_id
            end
        end
      end)
      |> generate_uuid_v7_list()

    {rows_to_insert, id_map, ids, skipped_from_existing, _generated_tail} =
      Enum.reduce(prepared, {[], %{}, MapSet.new(), 0, generated_ids}, fn row,
                                                                          {insert_rows, map,
                                                                           id_set, skipped,
                                                                           gen_ids} ->
        case extract_valid_uuid_id(row.raw_id) do
          valid_id when is_binary(valid_id) ->
            case Map.get(existing_owner_map, valid_id) do
              nil ->
                db_row =
                  row
                  |> Map.drop([:legacy_id, :raw_id])
                  |> Map.put(:id, uuid_to_db(valid_id))
                  |> Map.update!(:ash_user_id, &uuid_to_db/1)

                {[db_row | insert_rows], Map.put(map, row.legacy_id, valid_id),
                 MapSet.put(id_set, valid_id), skipped, gen_ids}

              owner_id when owner_id == row.ash_user_id ->
                {insert_rows, Map.put(map, row.legacy_id, valid_id), MapSet.put(id_set, valid_id),
                 skipped + 1, gen_ids}

              _other_owner ->
                [new_id | tail] = gen_ids

                db_row =
                  row
                  |> Map.drop([:legacy_id, :raw_id])
                  |> Map.put(:id, uuid_to_db(new_id))
                  |> Map.update!(:ash_user_id, &uuid_to_db/1)

                {[db_row | insert_rows], Map.put(map, row.legacy_id, new_id),
                 MapSet.put(id_set, new_id), skipped, tail}
            end

          _ ->
            [new_id | tail] = gen_ids

            db_row =
              row
              |> Map.drop([:legacy_id, :raw_id])
              |> Map.put(:id, uuid_to_db(new_id))
              |> Map.update!(:ash_user_id, &uuid_to_db/1)

            {[db_row | insert_rows], Map.put(map, row.legacy_id, new_id),
             MapSet.put(id_set, new_id), skipped, tail}
        end
      end)

    rows_to_insert = Enum.reverse(rows_to_insert)

    {inserted_count, insert_errors} =
      case rows_to_insert do
        [] ->
          {0, []}

        rows ->
          case Repo.insert_all("photos", rows, on_conflict: :nothing, conflict_target: [:id]) do
            {count, _} ->
              {count, []}

            error ->
              {0, [format_error(error)]}
          end
      end

    created = inserted_count
    skipped = skipped_from_existing + max(length(rows_to_insert) - inserted_count, 0)
    failed = length(insert_errors)
    errors = append_errors(errors, insert_errors)

    {%{created: created, skipped: skipped, failed: failed}, id_map, ids, errors}
  end

  defp import_notes(notes, target_user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    {prepared, errors} =
      Enum.reduce(notes, {[], []}, fn note, {rows, errs} ->
        legacy_id = pick_value(note, ["id", :id])
        text = pick_value(note, ["text", :text]) || ""

        photo_ids =
          note |> pick_value(["photo_ids", :photo_ids]) |> normalize_list() |> Enum.uniq()

        if is_nil(legacy_id) do
          {rows, add_error(errs, "Note missing id")}
        else
          row = %{
            legacy_id: legacy_id,
            raw_id: legacy_id,
            text: text,
            ash_user_id: target_user_id,
            photo_ids: photo_ids,
            inserted_at: parse_iso_datetime(pick_value(note, ["inserted_at", :inserted_at]), now),
            updated_at: parse_iso_datetime(pick_value(note, ["updated_at", :updated_at]), now)
          }

          {[row | rows], errs}
        end
      end)

    prepared = Enum.reverse(prepared)

    valid_uuid_ids =
      prepared |> Enum.map(&extract_valid_uuid_id(&1.raw_id)) |> Enum.reject(&is_nil/1)

    existing_owner_map = fetch_existing_owner_map("notes", valid_uuid_ids)

    generated_ids =
      prepared
      |> Enum.count(fn row ->
        case extract_valid_uuid_id(row.raw_id) do
          nil ->
            true

          valid_id ->
            case Map.get(existing_owner_map, valid_id) do
              nil -> false
              owner_id -> owner_id != row.ash_user_id
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
                  |> Map.drop([:legacy_id, :raw_id, :photo_ids])
                  |> Map.put(:id, uuid_to_db(valid_id))
                  |> Map.update!(:ash_user_id, &uuid_to_db/1)

                {[db_row | insert_rows], Map.put(map, row.legacy_id, valid_id),
                 Map.put(note_map, row.legacy_id, row.photo_ids), MapSet.put(id_set, valid_id),
                 skipped, gen_ids}

              owner_id when owner_id == row.ash_user_id ->
                {insert_rows, Map.put(map, row.legacy_id, valid_id),
                 Map.put(note_map, row.legacy_id, row.photo_ids), MapSet.put(id_set, valid_id),
                 skipped + 1, gen_ids}

              _other_owner ->
                [new_id | tail] = gen_ids

                db_row =
                  row
                  |> Map.drop([:legacy_id, :raw_id, :photo_ids])
                  |> Map.put(:id, uuid_to_db(new_id))
                  |> Map.update!(:ash_user_id, &uuid_to_db/1)

                {[db_row | insert_rows], Map.put(map, row.legacy_id, new_id),
                 Map.put(note_map, row.legacy_id, row.photo_ids), MapSet.put(id_set, new_id),
                 skipped, tail}
            end

          _ ->
            [new_id | tail] = gen_ids

            db_row =
              row
              |> Map.drop([:legacy_id, :raw_id, :photo_ids])
              |> Map.put(:id, uuid_to_db(new_id))
              |> Map.update!(:ash_user_id, &uuid_to_db/1)

            {[db_row | insert_rows], Map.put(map, row.legacy_id, new_id),
             Map.put(note_map, row.legacy_id, row.photo_ids), MapSet.put(id_set, new_id), skipped,
             tail}
        end
      end)

    rows_to_insert = Enum.reverse(rows_to_insert)

    {inserted_count, insert_errors} =
      case rows_to_insert do
        [] ->
          {0, []}

        rows ->
          case Repo.insert_all("notes", rows, on_conflict: :nothing, conflict_target: [:id]) do
            {count, _} ->
              {count, []}

            error ->
              {0, [format_error(error)]}
          end
      end

    created = inserted_count
    skipped = skipped_from_existing + max(length(rows_to_insert) - inserted_count, 0)
    failed = length(insert_errors)
    errors = append_errors(errors, insert_errors)

    {%{created: created, skipped: skipped, failed: failed}, id_map, note_photo_map, ids, errors}
  end

  defp import_photo_links(note_photo_map, photo_id_map, note_id_map, photo_ids, note_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    pairs =
      Enum.reduce(note_photo_map, MapSet.new(), fn {legacy_note_id, legacy_photo_ids}, acc ->
        note_id = Map.get(note_id_map, legacy_note_id)

        Enum.reduce(legacy_photo_ids, acc, fn legacy_photo_id, inner ->
          photo_id = Map.get(photo_id_map, legacy_photo_id)

          cond do
            is_nil(note_id) or is_nil(photo_id) ->
              inner

            not MapSet.member?(note_ids, note_id) or not MapSet.member?(photo_ids, photo_id) ->
              inner

            true ->
              MapSet.put(inner, {photo_id, note_id})
          end
        end)
      end)

    pair_list = MapSet.to_list(pairs)
    existing_pairs = fetch_existing_photo_note_pairs(pair_list)
    to_insert_pairs = Enum.reject(pair_list, &MapSet.member?(existing_pairs, &1))
    generated_ids = generate_uuid_v7_list(length(to_insert_pairs))

    rows_to_insert =
      Enum.zip(to_insert_pairs, generated_ids)
      |> Enum.map(fn {{photo_id, note_id}, id} ->
        %{
          id: uuid_to_db(id),
          photo_id: uuid_to_db(photo_id),
          note_id: uuid_to_db(note_id),
          inserted_at: now
        }
      end)

    {inserted_count, insert_errors} =
      case rows_to_insert do
        [] ->
          {0, []}

        rows ->
          case Repo.insert_all("photos_notes", rows,
                 on_conflict: :nothing,
                 conflict_target: [:photo_id, :note_id]
               ) do
            {count, _} ->
              {count, []}

            error ->
              {0, [format_error(error)]}
          end
      end

    skipped =
      MapSet.size(existing_pairs) + max(length(rows_to_insert) - inserted_count, 0)

    {%{created: inserted_count, skipped: skipped, failed: length(insert_errors)}, insert_errors}
  end

  defp sync_imported_typesense_documents(photo_ids, note_ids) do
    {photo_stats, photo_errors} =
      sync_typesense_records(
        MapSet.to_list(photo_ids),
        fn id -> Photo.sync_typesense_by_id(id, actor: nil, authorize?: false) end,
        "photo"
      )

    {note_stats, note_errors} =
      sync_typesense_records(
        MapSet.to_list(note_ids),
        fn id -> Note.sync_typesense_by_id(id, actor: nil, authorize?: false) end,
        "note"
      )

    {%{photos: photo_stats, notes: note_stats}, photo_errors ++ note_errors}
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
    first_photo = List.first(payload.typesense_photos || [])
    first_note = List.first(payload.typesense_notes || [])

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
    source_root = Path.join([tmp_dir, "storage", "v1", to_string(source_user_id || ""), "photos"])
    target_root = Path.join(["storage", "v1", target_user_id, "photos"])

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

  defp remap_photo_url(nil, _source_user_id, _target_user_id), do: nil

  defp remap_photo_url(url, source_user_id, target_user_id) do
    source_prefix =
      case source_user_id do
        nil -> nil
        id -> "/storage/v1/#{id}/photos/"
      end

    target_prefix = "/storage/v1/#{target_user_id}/photos/"

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

    with {:ok, metadata} <- read_json(Path.join(data_dir, "metadata.json")) do
      {:ok,
       %{
         metadata: metadata,
         user: read_optional_json(Path.join(data_dir, "user.json")) || %{},
         photos: normalize_list(read_optional_json(Path.join(data_dir, "photos.json"))),
         notes: normalize_list(read_optional_json(Path.join(data_dir, "notes.json"))),
         typesense_photos:
           normalize_list(read_optional_json(Path.join(data_dir, "typesense_photos.json"))),
         typesense_notes:
           normalize_list(read_optional_json(Path.join(data_dir, "typesense_notes.json")))
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_zip(zip_path, tmp_dir) do
    case :zip.extract(String.to_charlist(zip_path), [{:cwd, String.to_charlist(tmp_dir)}]) do
      {:ok, _files} -> :ok
      {:error, reason} -> {:error, "Failed to extract zip: #{inspect(reason)}"}
    end
  end

  defp write_json(path, data) do
    case Jason.encode(data, pretty: true) do
      {:ok, json} ->
        File.write(path, json)

      {:error, reason} ->
        {:error, "Failed to encode JSON #{path}: #{inspect(reason)}"}
    end
  end

  defp read_json(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, error} -> {:error, "Failed to decode JSON #{path}: #{inspect(error)}"}
        end

      {:error, reason} ->
        {:error, "Failed to read #{path}: #{inspect(reason)}"}
    end
  end

  defp read_optional_json(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> data
          {:error, _error} -> nil
        end

      {:error, _reason} ->
        nil
    end
  end

  defp zip_dir(source_dir, target_zip_path) do
    files =
      source_dir
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(&Path.relative_to(&1, source_dir))
      |> Enum.map(&String.to_charlist/1)

    case :zip.create(String.to_charlist(target_zip_path), files,
           cwd: String.to_charlist(source_dir)
         ) do
      {:ok, _filename} -> :ok
      {:error, reason} -> {:error, "Failed to create zip: #{inspect(reason)}"}
    end
  end

  defp build_typesense_photo_docs(photos, links, user_id) do
    photo_to_note_ids = invert_note_photo_links(links)

    Enum.reduce(photos, [], fn photo, acc ->
      case read_photo_image_base64(photo.url) do
        {:ok, image} ->
          inserted_at = datetime_to_unix(photo.inserted_at)

          doc = %{
            "id" => photo.id,
            "image" => image,
            "note" => photo.note || "",
            "caption" => photo.caption || "",
            "note_ids" => Map.get(photo_to_note_ids, photo.id, []),
            "url" => photo.url,
            "file_id" => photo.file_id,
            "inserted_at" => inserted_at,
            "inserted_by" => user_id,
            "_gen_ocr" => Map.get(photo, :ts_ocr)
          }

          [doc | acc]

        {:error, reason} ->
          Logger.warning("Skip typesense photo export for #{photo.id}: #{inspect(reason)}")
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
        "photo_ids" => pick_value(note, ["photo_ids", :photo_ids]) |> normalize_list(),
        "inserted_at" => iso8601_to_unix(pick_value(note, ["inserted_at", :inserted_at])),
        "updated_at" => iso8601_to_unix(pick_value(note, ["updated_at", :updated_at])),
        "belongs_to" => user_id
      }
    end)
  end

  defp invert_note_photo_links(links) do
    Enum.reduce(links, %{}, fn {note_id, photo_ids}, acc ->
      Enum.reduce(photo_ids, acc, fn photo_id, inner ->
        Map.update(inner, photo_id, [note_id], fn ids -> [note_id | ids] end)
      end)
    end)
    |> Enum.into(%{}, fn {photo_id, note_ids} ->
      {photo_id, note_ids |> Enum.uniq() |> Enum.reverse()}
    end)
  end

  defp read_photo_image_base64(url) when is_binary(url) do
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

  defp read_photo_image_base64(_url), do: {:error, :invalid_url}

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
      valid_uuid?(id) -> {:uuid, id}
      String.match?(id, ~r/^\d+$/) -> {:legacy, id}
      true -> :invalid
    end
  end

  defp normalize_record_id(id) when is_integer(id), do: {:legacy, id}
  defp normalize_record_id(_id), do: :invalid

  defp valid_uuid?(id) when is_binary(id) do
    Regex.match?(
      ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
      String.downcase(id)
    )
  end

  defp valid_uuid?(_id), do: false

  defp normalize_list(value) when is_list(value), do: value
  defp normalize_list(_value), do: []

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

  defp fetch_existing_owner_map(table, ids) when table in ["photos", "notes"] do
    query = "SELECT id::text, ash_user_id::text FROM #{table} WHERE id::text = ANY($1::text[])"

    case Repo.query(query, [ids]) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [id, owner_id] -> {id, owner_id} end)

      _ ->
        %{}
    end
  end

  defp fetch_existing_photo_note_pairs([]), do: MapSet.new()

  defp fetch_existing_photo_note_pairs(pairs) do
    {photo_ids, note_ids} = Enum.unzip(pairs)
    photo_ids = Enum.uniq(photo_ids)
    note_ids = Enum.uniq(note_ids)

    query = """
    SELECT photo_id::text, note_id::text
    FROM photos_notes
    WHERE photo_id::text = ANY($1::text[]) AND note_id::text = ANY($2::text[])
    """

    case Repo.query(query, [photo_ids, note_ids]) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(fn [photo_id, note_id] -> {photo_id, note_id} end)
        |> MapSet.new()

      _ ->
        MapSet.new()
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
    Enum.reduce(more, errors, fn error, acc ->
      add_error(acc, error)
    end)
  end

  defp add_error(errors, _error) when length(errors) >= @error_limit, do: errors
  defp add_error(errors, error), do: errors ++ [error]

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
