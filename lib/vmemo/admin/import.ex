defmodule Vmemo.Admin.Import do
  @moduledoc false
  require Ash.Query
  alias Vmemo.Account.User
  alias Vmemo.ImportExport.Errors
  alias Vmemo.ImportExport.Ids
  alias Vmemo.ImportExport.Json
  alias Vmemo.ImportExport.Zip
  alias Vmemo.Memo.Note
  alias Vmemo.Memo.Photo
  alias Vmemo.Memo.PhotoNote

  @error_limit 50

  def import_zip(zip_path, progress_fun \\ fn _progress -> :ok end) do
    tmp_dir = build_tmp_dir()

    result =
      with :ok <-
             report_progress(progress_fun, "Extracting zip", 10, fn ->
               extract_zip(zip_path, tmp_dir)
             end),
           {:ok, payload} <-
             report_progress(progress_fun, "Reading payload", 25, fn ->
               read_payload(tmp_dir)
             end),
           {:ok, import_result} <-
             report_progress(progress_fun, "Importing data", 40, fn ->
               import_payload(payload, tmp_dir, progress_fun)
             end) do
        {:ok, import_result}
      else
        {:error, reason} ->
          {:error, reason}
      end

    File.rm_rf(tmp_dir)
    result
  end

  defp extract_zip(zip_path, tmp_dir) do
    Zip.extract_zip(zip_path, tmp_dir)
  end

  defp read_payload(tmp_dir) do
    data_dir = Path.join(tmp_dir, "data")

    case read_json(Path.join(data_dir, "metadata.json")) do
      {:ok, metadata} ->
        users = read_optional_json(Path.join(data_dir, "users.json"))
        user = read_optional_json(Path.join(data_dir, "user.json"))
        photos = read_optional_json(Path.join(data_dir, "photos.json"))
        notes = read_optional_json(Path.join(data_dir, "notes.json"))

        users_list =
          cond do
            is_list(users) -> users
            is_map(user) -> [user]
            true -> []
          end

        {:ok,
         %{
           metadata: metadata,
           users: users_list,
           photos: normalize_list(photos),
           notes: normalize_list(notes)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_list(value), do: Json.normalize_list(value)

  defp read_json(path) do
    Json.read_json(path)
  end

  defp read_optional_json(path) do
    Json.read_optional_json(path)
  end

  defp import_payload(payload, tmp_dir, progress_fun) do
    file_stats =
      report_progress(progress_fun, "Copying files", 50, fn ->
        copy_storage_files(tmp_dir)
      end)

    {user_stats, user_id_map, user_errors} =
      report_progress(progress_fun, "Importing users", 60, fn ->
        import_users(payload.users)
      end)

    {photo_stats, photo_ids, photo_id_map, photo_errors} =
      report_progress(progress_fun, "Importing photos", 70, fn ->
        import_photos(payload.photos, user_id_map)
      end)

    {note_stats, note_ids, note_id_map, note_photo_map, note_errors} =
      report_progress(progress_fun, "Importing notes", 80, fn ->
        import_notes(payload.notes, user_id_map, photo_id_map)
      end)

    {photo_note_stats, photo_note_errors} =
      report_progress(progress_fun, "Importing links", 90, fn ->
        import_photo_notes(note_photo_map, photo_ids, note_ids, note_id_map)
      end)

    errors =
      []
      |> append_errors(user_errors)
      |> append_errors(photo_errors)
      |> append_errors(note_errors)
      |> append_errors(photo_note_errors)

    result = %{
      metadata: payload.metadata,
      files: file_stats,
      users: user_stats,
      photos: photo_stats,
      notes: note_stats,
      photo_notes: photo_note_stats,
      errors: errors,
      error_count: length(errors)
    }

    if errors == [] do
      report_progress(progress_fun, "Finalizing", 100, fn -> :ok end)
      {:ok, result}
    else
      report_progress(progress_fun, "Finalizing", 100, fn -> :ok end)
      {:error, result}
    end
  end

  defp import_users(users) do
    Enum.reduce(users, {%{created: 0, skipped: 0, remapped: 0, failed: 0}, %{}, []}, fn user,
                                                                                        {stats,
                                                                                         id_map,
                                                                                         errors} ->
      import_user_record(user, %{stats: stats, id_map: id_map, errors: errors})
    end)
  end

  defp import_user_record(user, state) do
    user_id = pick_value(user, ["id", :id])
    email = pick_value(user, ["email", :email])
    hashed_password = pick_value(user, ["hashed_password", :hashed_password])
    confirmed_at = pick_value(user, ["confirmed_at", :confirmed_at])
    %{stats: stats, id_map: id_map, errors: errors} = state

    if is_nil(email) do
      {bump(stats, :failed), id_map, add_error(errors, "User missing id or email")}
    else
      import_user_by_id_type(user_id, email, hashed_password, confirmed_at, stats, id_map, errors)
    end
  end

  defp import_user_by_id_type(
         user_id,
         email,
         hashed_password,
         confirmed_at,
         stats,
         id_map,
         errors
       ) do
    case normalize_user_id(user_id) do
      {:uuid, uuid} ->
        import_existing_or_new_user(
          uuid,
          user_id,
          email,
          hashed_password,
          confirmed_at,
          stats,
          id_map,
          errors
        )

      {:legacy, _legacy_id} ->
        create_or_remap_user(user_id, email, hashed_password, confirmed_at, stats, id_map, errors)

      :invalid ->
        {bump(stats, :failed), id_map,
         add_error(errors, "User #{email} has invalid id: #{inspect(user_id)}")}
    end
  end

  defp import_existing_or_new_user(
         uuid,
         user_id,
         email,
         hashed_password,
         confirmed_at,
         stats,
         id_map,
         errors
       ) do
    case Ash.get(User, uuid, actor: nil, authorize?: false) do
      {:ok, existing} ->
        {bump(stats, :skipped), Map.put(id_map, user_id, existing.id), errors}

      {:error, %Ash.Error.Query.NotFound{}} ->
        create_or_remap_user(user_id, email, hashed_password, confirmed_at, stats, id_map, errors)

      {:error, error} ->
        {bump(stats, :failed), id_map,
         add_error(errors, "User #{email} lookup failed: #{format_error(error)}")}
    end
  end

  defp create_or_remap_user(user_id, email, hashed_password, confirmed_at, stats, id_map, errors) do
    case get_user_by_email(email) do
      {:ok, %User{} = existing} ->
        {bump(stats, :remapped), Map.put(id_map, user_id, existing.id), errors}

      {:ok, nil} ->
        create_user(user_id, email, hashed_password, confirmed_at, stats, id_map, errors)

      {:error, error} ->
        {bump(stats, :failed), id_map,
         add_error(errors, "User #{email} lookup failed: #{format_error(error)}")}
    end
  end

  defp create_user(user_id, email, hashed_password, confirmed_at, stats, id_map, errors) do
    id_param =
      case normalize_user_id(user_id) do
        {:uuid, uuid} -> uuid
        _ -> nil
      end

    params =
      %{
        id: id_param,
        email: email,
        hashed_password: hashed_password,
        confirmed_at: confirmed_at
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})

    case Ash.create(User, params, action: :import, actor: nil, authorize?: false) do
      {:ok, created} ->
        {bump(stats, :created), Map.put(id_map, user_id, created.id), errors}

      {:error, error} ->
        {bump(stats, :failed), id_map,
         add_error(errors, "User #{email} import failed: #{format_error(error)}")}
    end
  end

  defp import_photos(photos, user_id_map) do
    Enum.reduce(photos, {%{created: 0, skipped: 0, failed: 0}, MapSet.new(), %{}, []}, fn photo,
                                                                                          {stats,
                                                                                           ids,
                                                                                           id_map,
                                                                                           errors} ->
      photo_id = pick_value(photo, ["id", :id])
      url = pick_value(photo, ["url", :url])
      note = pick_value(photo, ["note", :note])
      caption = pick_value(photo, ["caption", :caption])
      file_id = pick_value(photo, ["file_id", :file_id])
      inserted_by = pick_value(photo, ["inserted_by", :inserted_by, "user_id", :user_id])
      user_id = map_user_id(user_id_map, inserted_by)

      if is_nil(photo_id) or is_nil(url) do
        {bump(stats, :failed), ids, id_map, add_error(errors, "Photo missing id or url")}
      else
        import_photo_record(
          %{
            photo_id: photo_id,
            url: url,
            note: note,
            caption: caption,
            file_id: file_id,
            user_id: user_id
          },
          %{stats: stats, ids: ids, id_map: id_map, errors: errors}
        )
      end
    end)
  end

  defp import_notes(notes, user_id_map, photo_id_map) do
    Enum.reduce(
      notes,
      {%{created: 0, skipped: 0, failed: 0}, MapSet.new(), %{}, %{}, []},
      fn note, {stats, ids, id_map, note_map, errors} ->
        note_id = pick_value(note, ["id", :id])

        text =
          note
          |> pick_value(["text", :text])
          |> normalize_note_text()

        belongs_to = pick_value(note, ["belongs_to", :belongs_to, "user_id", :user_id])
        user_id = map_user_id(user_id_map, belongs_to)

        photo_ids =
          note
          |> pick_value(["photo_ids", :photo_ids])
          |> normalize_list()
          |> Enum.map(&map_photo_id(photo_id_map, &1))
          |> Enum.reject(&is_nil/1)

        if is_nil(note_id) do
          {bump(stats, :failed), ids, id_map, note_map,
           add_error(errors, "Note missing id or text")}
        else
          import_note_record(
            %{note_id: note_id, text: text, user_id: user_id, photo_ids: photo_ids},
            %{stats: stats, ids: ids, id_map: id_map, note_map: note_map, errors: errors}
          )
        end
      end
    )
  end

  defp import_photo_notes(note_photo_map, photo_ids, note_ids, note_id_map) do
    Enum.reduce(note_photo_map, {%{created: 0, skipped: 0, failed: 0}, []}, fn {note_id, ids},
                                                                               {stats, errors} ->
      Enum.reduce(ids, {stats, errors}, fn photo_id, {inner_stats, inner_errors} ->
        resolved_note_id = map_note_id(note_id_map, note_id)

        import_photo_note_link(
          photo_id,
          resolved_note_id,
          %{stats: inner_stats, errors: inner_errors},
          %{photo_ids: photo_ids, note_ids: note_ids}
        )
      end)
    end)
  end

  defp import_photo_note_link(photo_id, note_id, state, valid_ids) do
    %{stats: stats, errors: errors} = state
    %{photo_ids: photo_ids, note_ids: note_ids} = valid_ids

    if should_skip_photo_note_link?(photo_id, note_id, photo_ids, note_ids) do
      {bump(stats, :skipped), errors}
    else
      create_photo_note_link(photo_id, note_id, stats, errors)
    end
  end

  defp should_skip_photo_note_link?(photo_id, note_id, photo_ids, note_ids) do
    is_nil(note_id) or
      not valid_uuid?(note_id) or
      not MapSet.member?(photo_ids, photo_id) or
      not MapSet.member?(note_ids, note_id)
  end

  defp create_photo_note_link(photo_id, note_id, stats, errors) do
    case photo_note_exists?(photo_id, note_id) do
      {:ok, true} ->
        {bump(stats, :skipped), errors}

      {:ok, false} ->
        do_create_photo_note_link(photo_id, note_id, stats, errors)

      {:error, error} ->
        {bump(stats, :failed),
         add_error(
           errors,
           "Photo note link lookup failed (#{photo_id}, #{note_id}): #{format_error(error)}"
         )}
    end
  end

  defp do_create_photo_note_link(photo_id, note_id, stats, errors) do
    params = %{photo_id: photo_id, note_id: note_id}

    case Ash.create(PhotoNote, params, action: :import, actor: nil, authorize?: false) do
      {:ok, _created} ->
        {bump(stats, :created), errors}

      {:error, error} ->
        {bump(stats, :failed),
         add_error(
           errors,
           "Photo note link failed (#{photo_id}, #{note_id}): #{format_error(error)}"
         )}
    end
  end

  defp photo_note_exists?(photo_id, note_id) do
    query =
      PhotoNote
      |> Ash.Query.filter(photo_id: photo_id, note_id: note_id)
      |> Ash.Query.limit(1)

    case Ash.read(query, actor: nil, authorize?: false) do
      {:ok, []} -> {:ok, false}
      {:ok, _} -> {:ok, true}
      {:error, error} -> {:error, error}
    end
  end

  defp copy_storage_files(tmp_dir) do
    source_root = Path.join(tmp_dir, "storage")

    if File.exists?(source_root) do
      files =
        source_root
        |> Path.join("**/*")
        |> Path.wildcard()
        |> Enum.filter(&File.regular?/1)

      Enum.reduce(files, %{copied: 0, skipped: 0}, fn source, acc ->
        rel_path = Path.relative_to(source, tmp_dir)
        dest = Path.expand(rel_path, File.cwd!())
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

  defp build_tmp_dir do
    base = System.tmp_dir!()
    tmp_dir = Path.join(base, "vmemo-import-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    tmp_dir
  end

  defp report_progress(progress_fun, stage, percent, fun) do
    progress_fun.(%{stage: stage, percent: percent})
    fun.()
  end

  defp pick_value(map, keys) when is_map(map) do
    Enum.find_value(keys, fn key ->
      case key do
        atom when is_atom(atom) -> Map.get(map, atom)
        string when is_binary(string) -> Map.get(map, string)
      end
    end)
  end

  defp pick_value(_map, _keys), do: nil

  defp map_user_id(_user_id_map, nil), do: nil

  defp map_user_id(user_id_map, user_id) do
    Map.get(user_id_map, user_id, fallback_user_id(user_id, user_id_map))
  end

  defp map_photo_id(photo_id_map, photo_id) do
    Map.get(photo_id_map, photo_id, fallback_user_id(photo_id, photo_id_map))
  end

  defp map_note_id(note_id_map, note_id) do
    Map.get(note_id_map, note_id, fallback_user_id(note_id, note_id_map))
  end

  defp import_photo_record(photo_payload, state) do
    %{
      photo_id: photo_id,
      url: url,
      note: note,
      caption: caption,
      file_id: file_id,
      user_id: user_id
    } =
      photo_payload

    %{stats: stats, ids: ids, id_map: id_map, errors: errors} = state

    case normalize_record_id(photo_id) do
      {:uuid, uuid} ->
        case Ash.get(Photo, uuid, actor: nil, authorize?: false) do
          {:ok, _existing} ->
            {bump(stats, :skipped), MapSet.put(ids, uuid), Map.put(id_map, photo_id, uuid),
             errors}

          {:error, %Ash.Error.Query.NotFound{}} ->
            create_photo(
              %{
                id: uuid,
                url: url,
                note: note,
                caption: caption,
                file_id: file_id,
                user_id: user_id
              },
              %{stats: stats, ids: ids, id_map: id_map, errors: errors}
            )

          {:error, error} ->
            {bump(stats, :failed), ids, id_map,
             add_error(errors, "Photo #{photo_id} lookup failed: #{format_error(error)}")}
        end

      {:legacy, _legacy_id} ->
        create_photo(
          %{id: nil, url: url, note: note, caption: caption, file_id: file_id, user_id: user_id},
          %{stats: stats, ids: ids, id_map: id_map, errors: errors},
          legacy_id: photo_id
        )

      :invalid ->
        {bump(stats, :failed), ids, id_map,
         add_error(errors, "Photo has invalid id: #{inspect(photo_id)}")}
    end
  end

  defp create_photo(photo_payload, state, opts \\ []) do
    %{id: uuid, url: url, note: note, caption: caption, file_id: file_id, user_id: user_id} =
      photo_payload

    %{stats: stats, ids: ids, id_map: id_map, errors: errors} = state

    params =
      %{
        id: uuid,
        url: url,
        note: note,
        caption: caption,
        file_id: file_id,
        user_id: user_id
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})

    case Ash.create(Photo, params, action: :import, actor: nil, authorize?: false) do
      {:ok, created} ->
        legacy_id = Keyword.get(opts, :legacy_id, created.id)

        {bump(stats, :created), MapSet.put(ids, created.id),
         Map.put(id_map, legacy_id, created.id), errors}

      {:error, error} ->
        {bump(stats, :failed), ids, id_map,
         add_error(
           errors,
           "Photo #{inspect(uuid || opts[:legacy_id])} import failed: #{format_error(error)}"
         )}
    end
  end

  defp import_note_record(note_payload, state) do
    %{note_id: note_id, text: text, user_id: user_id, photo_ids: photo_ids} = note_payload
    %{stats: stats, ids: ids, id_map: id_map, note_map: note_map, errors: errors} = state

    case normalize_record_id(note_id) do
      {:uuid, uuid} ->
        case Ash.get(Note, uuid, actor: nil, authorize?: false) do
          {:ok, _existing} ->
            {bump(stats, :skipped), MapSet.put(ids, uuid), Map.put(id_map, note_id, uuid),
             Map.put(note_map, uuid, photo_ids), errors}

          {:error, %Ash.Error.Query.NotFound{}} ->
            create_note(
              %{id: uuid, text: text, user_id: user_id, photo_ids: photo_ids},
              %{stats: stats, ids: ids, id_map: id_map, note_map: note_map, errors: errors}
            )

          {:error, error} ->
            {bump(stats, :failed), ids, id_map, note_map,
             add_error(errors, "Note #{note_id} lookup failed: #{format_error(error)}")}
        end

      {:legacy, _legacy_id} ->
        create_note(
          %{id: nil, text: text, user_id: user_id, photo_ids: photo_ids},
          %{stats: stats, ids: ids, id_map: id_map, note_map: note_map, errors: errors},
          legacy_id: note_id
        )

      :invalid ->
        {bump(stats, :failed), ids, id_map, note_map,
         add_error(errors, "Note has invalid id: #{inspect(note_id)}")}
    end
  end

  defp create_note(note_payload, state, opts \\ []) do
    %{id: uuid, text: text, user_id: user_id, photo_ids: photo_ids} = note_payload
    %{stats: stats, ids: ids, id_map: id_map, note_map: note_map, errors: errors} = state

    params =
      %{
        id: uuid,
        text: text,
        user_id: user_id
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})

    case Ash.create(Note, params, action: :import, actor: nil, authorize?: false) do
      {:ok, created} ->
        legacy_id = Keyword.get(opts, :legacy_id, created.id)

        {bump(stats, :created), MapSet.put(ids, created.id),
         Map.put(id_map, legacy_id, created.id), Map.put(note_map, created.id, photo_ids), errors}

      {:error, error} ->
        {bump(stats, :failed), ids, id_map, note_map,
         add_error(
           errors,
           "Note #{inspect(uuid || opts[:legacy_id])} import failed: #{format_error(error)}"
         )}
    end
  end

  defp fallback_user_id(user_id, user_id_map) when is_binary(user_id) do
    case Integer.parse(user_id) do
      {int_id, ""} ->
        Map.get(user_id_map, int_id, user_id)

      _ ->
        user_id
    end
  end

  defp fallback_user_id(user_id, user_id_map) when is_integer(user_id) do
    Map.get(user_id_map, Integer.to_string(user_id), user_id)
  end

  defp fallback_user_id(user_id, _user_id_map), do: user_id

  defp normalize_user_id(nil), do: :invalid
  defp normalize_user_id(user_id), do: normalize_record_id(user_id)

  defp normalize_record_id(id) when is_binary(id) do
    cond do
      Ids.valid_uuid?(id) -> {:uuid, id}
      String.match?(id, ~r/^\d+$/) -> {:legacy, id}
      true -> :invalid
    end
  end

  defp normalize_record_id(id) when is_integer(id), do: Ids.normalize_record_id(id)
  defp normalize_record_id(_id), do: Ids.normalize_record_id(nil)
  defp valid_uuid?(id), do: Ids.valid_uuid?(id)

  defp normalize_note_text(nil), do: ""
  defp normalize_note_text(text) when is_binary(text), do: text
  defp normalize_note_text(_text), do: ""

  defp get_user_by_email(email) do
    query =
      User
      |> Ash.Query.filter(email: email)
      |> Ash.Query.limit(1)

    case Ash.read(query, actor: nil, authorize?: false) do
      {:ok, [user | _rest]} -> {:ok, user}
      {:ok, []} -> {:ok, nil}
      {:error, error} -> {:error, error}
    end
  end

  defp bump(stats, key) do
    Map.update(stats, key, 1, &(&1 + 1))
  end

  defp append_errors(errors, more) do
    Errors.append_errors(errors, more)
    |> Enum.take(@error_limit)
  end

  defp add_error(errors, error), do: Errors.add_error(errors, error, @error_limit)
  defp format_error(error), do: Errors.format_error(error)
end
