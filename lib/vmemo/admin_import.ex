defmodule Vmemo.AdminImport do
  require Ash.Query
  alias Vmemo.Account.AshUser
  alias Vmemo.Photos.Note
  alias Vmemo.Photos.Photo
  alias Vmemo.Photos.PhotoNote

  @error_limit 50

  def import_zip(zip_path) do
    tmp_dir = build_tmp_dir()

    result =
      with :ok <- extract_zip(zip_path, tmp_dir),
           {:ok, payload} <- read_payload(tmp_dir),
           {:ok, import_result} <- import_payload(payload, tmp_dir) do
        {:ok, import_result}
      else
        {:error, reason} ->
          {:error, reason}
      end

    File.rm_rf(tmp_dir)
    result
  end

  defp extract_zip(zip_path, tmp_dir) do
    case :zip.extract(String.to_charlist(zip_path), [{:cwd, String.to_charlist(tmp_dir)}]) do
      {:ok, _files} -> :ok
      {:error, reason} -> {:error, "Failed to extract zip: #{inspect(reason)}"}
    end
  end

  defp read_payload(tmp_dir) do
    data_dir = Path.join(tmp_dir, "data")

    with {:ok, metadata} <- read_json(Path.join(data_dir, "metadata.json")) do
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
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_list(value) when is_list(value), do: value
  defp normalize_list(_value), do: []

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

  defp import_payload(payload, tmp_dir) do
    file_stats = copy_storage_files(tmp_dir)

    {user_stats, user_id_map, user_errors} = import_users(payload.users)

    {photo_stats, photo_ids, photo_id_map, photo_errors} =
      import_photos(payload.photos, user_id_map)

    {note_stats, note_ids, note_id_map, note_photo_map, note_errors} =
      import_notes(payload.notes, user_id_map, photo_id_map)

    {photo_note_stats, photo_note_errors} =
      import_photo_notes(note_photo_map, photo_ids, note_ids, note_id_map)

    sync_typesense(photo_ids, note_ids)

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
      {:ok, result}
    else
      {:error, result}
    end
  end

  defp import_users(users) do
    Enum.reduce(users, {%{created: 0, skipped: 0, remapped: 0, failed: 0}, %{}, []}, fn user,
                                                                                        {stats,
                                                                                         id_map,
                                                                                         errors} ->
      user_id = pick_value(user, ["id", :id])
      email = pick_value(user, ["email", :email])
      hashed_password = pick_value(user, ["hashed_password", :hashed_password])
      confirmed_at = pick_value(user, ["confirmed_at", :confirmed_at])

      cond do
        is_nil(email) ->
          {bump(stats, :failed), id_map, add_error(errors, "User missing id or email")}

        true ->
          case normalize_user_id(user_id) do
            {:uuid, uuid} ->
              case Ash.get(AshUser, uuid, actor: nil, authorize?: false) do
                {:ok, existing} ->
                  {bump(stats, :skipped), Map.put(id_map, user_id, existing.id), errors}

                {:error, %Ash.Error.Query.NotFound{}} ->
                  create_or_remap_user(
                    user_id,
                    email,
                    hashed_password,
                    confirmed_at,
                    stats,
                    id_map,
                    errors
                  )

                {:error, error} ->
                  {bump(stats, :failed), id_map,
                   add_error(errors, "User #{email} lookup failed: #{format_error(error)}")}
              end

            {:legacy, _legacy_id} ->
              create_or_remap_user(
                user_id,
                email,
                hashed_password,
                confirmed_at,
                stats,
                id_map,
                errors
              )

            :invalid ->
              {bump(stats, :failed), id_map,
               add_error(errors, "User #{email} has invalid id: #{inspect(user_id)}")}
          end
      end
    end)
  end

  defp create_or_remap_user(user_id, email, hashed_password, confirmed_at, stats, id_map, errors) do
    case get_user_by_email(email) do
      {:ok, %AshUser{} = existing} ->
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

    case Ash.create(AshUser, params, action: :import, actor: nil, authorize?: false) do
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
      inserted_by = pick_value(photo, ["inserted_by", :inserted_by, "ash_user_id", :ash_user_id])
      ash_user_id = map_user_id(user_id_map, inserted_by)

      cond do
        is_nil(photo_id) or is_nil(url) ->
          {bump(stats, :failed), ids, id_map, add_error(errors, "Photo missing id or url")}

        true ->
          import_photo_record(
            photo_id,
            url,
            note,
            caption,
            file_id,
            ash_user_id,
            stats,
            ids,
            id_map,
            errors
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

        belongs_to = pick_value(note, ["belongs_to", :belongs_to, "ash_user_id", :ash_user_id])
        ash_user_id = map_user_id(user_id_map, belongs_to)

        photo_ids =
          note
          |> pick_value(["photo_ids", :photo_ids])
          |> normalize_list()
          |> Enum.map(&map_photo_id(photo_id_map, &1))
          |> Enum.reject(&is_nil/1)

        cond do
          is_nil(note_id) ->
            {bump(stats, :failed), ids, id_map, note_map,
             add_error(errors, "Note missing id or text")}

          true ->
            import_note_record(
              note_id,
              text,
              ash_user_id,
              photo_ids,
              stats,
              ids,
              id_map,
              note_map,
              errors
            )
        end
      end
    )
  end

  defp import_photo_notes(note_photo_map, photo_ids, note_ids, note_id_map) do
    Enum.reduce(note_photo_map, {%{created: 0, skipped: 0, failed: 0}, []}, fn {note_id, ids},
                                                                               {stats, errors} ->
      Enum.reduce(ids, {stats, errors}, fn photo_id, {inner_stats, inner_errors} ->
        note_id = map_note_id(note_id_map, note_id)

        cond do
          is_nil(note_id) or not valid_uuid?(note_id) ->
            {bump(inner_stats, :skipped), inner_errors}

          not MapSet.member?(photo_ids, photo_id) ->
            {bump(inner_stats, :skipped), inner_errors}

          not MapSet.member?(note_ids, note_id) ->
            {bump(inner_stats, :skipped), inner_errors}

          true ->
            case photo_note_exists?(photo_id, note_id) do
              {:ok, true} ->
                {bump(inner_stats, :skipped), inner_errors}

              {:ok, false} ->
                params = %{photo_id: photo_id, note_id: note_id}

                case Ash.create(PhotoNote, params,
                       action: :import,
                       actor: nil,
                       authorize?: false
                     ) do
                  {:ok, _created} ->
                    {bump(inner_stats, :created), inner_errors}

                  {:error, error} ->
                    {bump(inner_stats, :failed),
                     add_error(
                       inner_errors,
                       "Photo note link failed (#{photo_id}, #{note_id}): #{format_error(error)}"
                     )}
                end

              {:error, error} ->
                {bump(inner_stats, :failed),
                 add_error(
                   inner_errors,
                   "Photo note link lookup failed (#{photo_id}, #{note_id}): #{format_error(error)}"
                 )}
            end
        end
      end)
    end)
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

  defp sync_typesense(photo_ids, note_ids) do
    Enum.each(photo_ids, fn photo_id ->
      %{photo_id: photo_id}
      |> Vmemo.Workers.SyncPhotoToTypesense.new()
      |> Oban.insert()
    end)

    Enum.each(note_ids, fn note_id ->
      %{note_id: note_id}
      |> Vmemo.Workers.SyncNoteToTypesense.new()
      |> Oban.insert()
    end)
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

  defp import_photo_record(
         photo_id,
         url,
         note,
         caption,
         file_id,
         ash_user_id,
         stats,
         ids,
         id_map,
         errors
       ) do
    case normalize_record_id(photo_id) do
      {:uuid, uuid} ->
        case Ash.get(Photo, uuid, actor: nil, authorize?: false) do
          {:ok, _existing} ->
            {bump(stats, :skipped), MapSet.put(ids, uuid), Map.put(id_map, photo_id, uuid),
             errors}

          {:error, %Ash.Error.Query.NotFound{}} ->
            create_photo(
              uuid,
              url,
              note,
              caption,
              file_id,
              ash_user_id,
              stats,
              ids,
              id_map,
              errors
            )

          {:error, error} ->
            {bump(stats, :failed), ids, id_map,
             add_error(errors, "Photo #{photo_id} lookup failed: #{format_error(error)}")}
        end

      {:legacy, _legacy_id} ->
        create_photo(nil, url, note, caption, file_id, ash_user_id, stats, ids, id_map, errors,
          legacy_id: photo_id
        )

      :invalid ->
        {bump(stats, :failed), ids, id_map,
         add_error(errors, "Photo has invalid id: #{inspect(photo_id)}")}
    end
  end

  defp create_photo(
         uuid,
         url,
         note,
         caption,
         file_id,
         ash_user_id,
         stats,
         ids,
         id_map,
         errors,
         opts \\ []
       ) do
    params =
      %{
        id: uuid,
        url: url,
        note: note,
        caption: caption,
        file_id: file_id,
        ash_user_id: ash_user_id
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

  defp import_note_record(
         note_id,
         text,
         ash_user_id,
         photo_ids,
         stats,
         ids,
         id_map,
         note_map,
         errors
       ) do
    case normalize_record_id(note_id) do
      {:uuid, uuid} ->
        case Ash.get(Note, uuid, actor: nil, authorize?: false) do
          {:ok, _existing} ->
            {bump(stats, :skipped), MapSet.put(ids, uuid), Map.put(id_map, note_id, uuid),
             Map.put(note_map, uuid, photo_ids), errors}

          {:error, %Ash.Error.Query.NotFound{}} ->
            create_note(uuid, text, ash_user_id, photo_ids, stats, ids, id_map, note_map, errors)

          {:error, error} ->
            {bump(stats, :failed), ids, id_map, note_map,
             add_error(errors, "Note #{note_id} lookup failed: #{format_error(error)}")}
        end

      {:legacy, _legacy_id} ->
        create_note(nil, text, ash_user_id, photo_ids, stats, ids, id_map, note_map, errors,
          legacy_id: note_id
        )

      :invalid ->
        {bump(stats, :failed), ids, id_map, note_map,
         add_error(errors, "Note has invalid id: #{inspect(note_id)}")}
    end
  end

  defp create_note(
         uuid,
         text,
         ash_user_id,
         photo_ids,
         stats,
         ids,
         id_map,
         note_map,
         errors,
         opts \\ []
       ) do
    params =
      %{
        id: uuid,
        text: text,
        ash_user_id: ash_user_id
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

  defp normalize_note_text(nil), do: ""
  defp normalize_note_text(text) when is_binary(text), do: text
  defp normalize_note_text(_text), do: ""

  defp get_user_by_email(email) do
    query =
      AshUser
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
    Enum.reduce(more, errors, fn error, acc ->
      add_error(acc, error)
    end)
  end

  defp add_error(errors, _error) when length(errors) >= @error_limit, do: errors
  defp add_error(errors, error), do: errors ++ [error]

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
