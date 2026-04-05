defmodule Vmemo.Photos.Photo do
  @derive {Jason.Encoder,
           only: [
             :id,
             :url,
             :note,
             :caption,
             :ts_ocr,
             :file_id,
             :user_id,
             :inserted_at,
             :updated_at
           ]}
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource, AshOban]

  require Ash.Query
  alias SmallSdk.Moondream
  alias Vmemo.Repo.RLS
  alias Vmemo.PhotoService.TsPhoto

  postgres do
    table "photos"
    repo Vmemo.Repo

    custom_statements do
      statement :rls_photos_isolation do
        up """
        ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
        ALTER TABLE photos FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS photos_rls_isolation ON photos;
        CREATE POLICY photos_rls_isolation ON photos
          USING (
            CASE
              WHEN current_setting('vmemo.rls_bypass', true) = 'on' THEN true
              ELSE user_id IS NOT NULL
                   AND user_id = nullif(current_setting('vmemo.current_actor_id', true), '')::uuid
            END
          )
          WITH CHECK (
            CASE
              WHEN current_setting('vmemo.rls_bypass', true) = 'on' THEN true
              ELSE user_id IS NOT NULL
                   AND user_id = nullif(current_setting('vmemo.current_actor_id', true), '')::uuid
            END
          );
        """

        down """
        DROP POLICY IF EXISTS photos_rls_isolation ON photos;
        ALTER TABLE photos NO FORCE ROW LEVEL SECURITY;
        ALTER TABLE photos DISABLE ROW LEVEL SECURITY;
        """
      end
    end
  end

  admin do
    table_columns([:id, :url, :note, :caption, :ts_ocr, :user_id, :inserted_at])
  end

  oban do
    triggers do
      trigger :sync_typesense do
        action :sync_typesense
        queue :sync_typesense
        scheduler_cron false
        where expr(true)
        worker_module_name Vmemo.Photos.Photo.Workers.SyncTypesense
        scheduler_module_name Vmemo.Photos.Photo.Schedulers.SyncTypesense
      end

      trigger :generate_caption do
        action :generate_caption
        queue :default
        scheduler_cron false
        where expr(true)
        worker_module_name Vmemo.Photos.Photo.Workers.GenerateCaption
        scheduler_module_name Vmemo.Photos.Photo.Schedulers.GenerateCaption
      end
    end
  end

  code_interface do
    define :create_with_sync
    define :create_immediate
    define :read
    define :update
    define :destroy
    define :get_with_notes, args: [:id, :user_id]
    define :hybrid_search, args: [:query, :similar_photo_id, :user_id, :page]
    define :hybrid_search_count, args: [:query, :similar_photo_id, :user_id]
    define :list_similar, args: [:photo_id, :user_id]
    define :gen_description
    define :sync_typesense_by_id, args: [:photo_id]
  end

  defp valid_uuid?(id) when is_binary(id) do
    # Simple UUID validation (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
    Regex.match?(
      ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
      String.downcase(id)
    )
  end

  defp valid_uuid?(_), do: false

  actions do
    defaults [:read, :destroy]

    create :create_immediate do
      accept [:url, :note, :caption, :ts_ocr, :file_id, :user_id]
    end

    create :import do
      accept [:id, :url, :note, :caption, :ts_ocr, :file_id, :user_id]
    end

    create :create_with_sync do
      accept [:url, :note, :caption, :ts_ocr, :file_id, :user_id]
      change run_oban_trigger(:sync_typesense)
      change run_oban_trigger(:generate_caption)
    end

    update :update do
      accept [:note, :caption, :ts_ocr, :url]
      require_atomic? false
      change run_oban_trigger(:sync_typesense)
    end

    update :sync_typesense do
      accept []
      require_atomic? false
      transaction? false

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn _changeset, record ->
          RLS.with_bypass(fn ->
            case __MODULE__.sync_typesense_by_id(record.id, actor: nil, authorize?: false) do
              {:ok, true} ->
                {:ok, record}

              {:ok, false} ->
                {:error, :sync_failed}

              {:error, reason} ->
                {:error, reason}
            end
          end)
        end)
      end
    end

    update :generate_caption do
      accept []
      require_atomic? false
      transaction? false

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn _changeset, record ->
          case generate_caption_for_photo(record) do
            :ok ->
              {:ok, record}

            {:discard, _reason} ->
              {:ok, record}

            {:error, reason} ->
              {:error, reason}
          end
        end)
      end
    end

    action :sync_typesense_by_id, :boolean do
      argument :photo_id, :uuid, allow_nil?: false

      run fn input, _context ->
        photo_id = Ash.ActionInput.get_argument(input, :photo_id)

        RLS.with_bypass(fn ->
          with {:ok, photo} <- Ash.get(__MODULE__, photo_id, actor: nil, authorize?: false),
               {:ok, photo_with_notes} <- Ash.load(photo, :notes, actor: nil, authorize?: false),
               {:ok, _} <- upsert_typesense_photo(photo_with_notes) do
            {:ok, true}
          end
        end)
      end
    end

    read :get_with_notes do
      get? true
      argument :id, :string, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id) and user_id == ^arg(:user_id))

      prepare fn query, _context ->
        Ash.Query.load(query, :notes)
      end
    end

    read :hybrid_search do
      argument :query, :string
      argument :similar_photo_id, :string
      argument :user_id, :uuid, allow_nil?: false
      argument :page, :integer, default: 1

      prepare fn query, _context ->
        q = Ash.Query.get_argument(query, :query) || ""
        similar = Ash.Query.get_argument(query, :similar_photo_id)
        user_id = Ash.Query.get_argument(query, :user_id)
        page = Ash.Query.get_argument(query, :page)

        if blank_query_without_similar?(q, similar) do
          per_page = 10
          offset = (page - 1) * per_page

          Ash.Query.filter(query, user_id == ^user_id)
          |> Ash.Query.sort(inserted_at: :desc)
          |> Ash.Query.offset(offset)
          |> Ash.Query.limit(per_page)
        else
          {photos, _found, _current_page} =
            typesense_hybrid_search(q, similar, user_id, page)

          photo_ids =
            photos
            |> Enum.map(& &1.id)
            |> Enum.filter(&valid_uuid?/1)

          if photo_ids == [] do
            Ash.Query.filter(query, id: [in: []])
          else
            query
            |> Ash.Query.filter(id: [in: photo_ids])
            |> Ash.Query.after_action(fn _query, records ->
              photos_by_id = Map.new(photos, fn photo -> {photo.id, photo} end)

              sorted_records =
                photo_ids
                |> Enum.map(fn id ->
                  Enum.find(records, fn record -> record.id == id end)
                end)
                |> Enum.reject(&is_nil/1)
                |> Enum.map(fn record ->
                  case Map.get(photos_by_id, record.id) do
                    nil ->
                      record

                    ts_photo ->
                      Map.merge(record, %{
                        _vector_distance: ts_photo._vector_distance,
                        _text_match_info: ts_photo._text_match_info
                      })
                  end
                end)

              {:ok, sorted_records}
            end)
          end
        end
      end
    end

    action :hybrid_search_count, :integer do
      argument :query, :string
      argument :similar_photo_id, :string
      argument :user_id, :uuid, allow_nil?: false

      run fn input, context ->
        q = Ash.ActionInput.get_argument(input, :query) || ""
        similar = Ash.ActionInput.get_argument(input, :similar_photo_id)
        user_id = Ash.ActionInput.get_argument(input, :user_id)

        if blank_query_without_similar?(q, similar) do
          __MODULE__
          |> Ash.Query.filter(user_id == ^user_id)
          |> Ash.count(actor: context.actor)
        else
          {_photos, found, _current_page} =
            typesense_hybrid_search(q, similar, user_id, 1)

          {:ok, found}
        end
      end
    end

    action :search_photos, :string do
      description "Search photos by text query or find similar photos. Returns JSON array of image data URLs (data:image/{type};base64,...) for direct image display."

      argument :query, :string, default: ""
      argument :similar_photo_id, :string, allow_nil?: true
      argument :page, :integer, default: 1

      run fn input, context ->
        q = Ash.ActionInput.get_argument(input, :query) || ""
        similar = Ash.ActionInput.get_argument(input, :similar_photo_id)
        page = Ash.ActionInput.get_argument(input, :page) || 1

        # Get actor from context
        actor = Map.get(context, :actor)
        user_id = if actor, do: actor.id, else: nil

        if is_nil(user_id) do
          {:error, "Actor is required for photo search"}
        else
          {photos, _found, _current_page} =
            TsPhoto.hybird_search_photos({q, similar},
              user_id: user_id,
              page: page
            )

          photo_ids =
            photos
            |> Enum.map(& &1.id)
            |> Enum.filter(&valid_uuid?/1)

          if photo_ids == [] do
            {:ok, Jason.encode!([])}
          else
            query =
              __MODULE__
              |> Ash.Query.filter(id: [in: photo_ids])

            case Ash.read(query, actor: actor) do
              {:ok, records} ->
                sorted_records =
                  photo_ids
                  |> Enum.map(fn id ->
                    Enum.find(records, fn record -> record.id == id end)
                  end)
                  |> Enum.reject(&is_nil/1)
                  |> Enum.map(&normalize_photo_url_for_api/1)

                image_data_urls =
                  sorted_records
                  |> Enum.map(fn photo ->
                    case read_image_as_base64(photo.url) do
                      {:ok, {base64_data, mime_type}} ->
                        "data:#{mime_type};base64,#{base64_data}"

                      {:error, _reason} ->
                        # Fallback to URL if image read fails
                        photo.url
                    end
                  end)

                {:ok, Jason.encode!(image_data_urls)}

              {:error, reason} ->
                {:error, reason}
            end
          end
        end
      end
    end

    # MCP Resource action: Return photo URL as string
    # URI format: vmemo://photo/{id}/url
    # The id will be extracted from the URI and passed as a parameter
    action :get_photo_url, :string do
      description "Get the URL of a photo by ID. Returns the photo URL as a string."

      argument :uri, :string, allow_nil?: false

      run fn input, context ->
        uri = Ash.ActionInput.get_argument(input, :uri)
        actor = Map.get(context, :actor)

        # Extract photo ID from URI: vmemo://photo/{id}/url
        id = extract_photo_id_from_uri(uri)

        if is_nil(id) do
          {:error, "Invalid URI format. Expected: vmemo://photo/{id}/url"}
        else
          case Ash.get(__MODULE__, id, actor: actor) do
            {:ok, photo} ->
              normalized_photo = normalize_photo_url_for_api(photo)
              {:ok, normalized_photo.url}

            {:error, reason} ->
              {:error, reason}
          end
        end
      end
    end

    # MCP Resource action: Return photo as HTML
    # URI format: vmemo://photo/{id}/html
    # The id will be extracted from the URI and passed as a parameter
    action :get_photo_html, :string do
      description "Get a photo as HTML. Returns an HTML img tag with the photo URL, caption, and note."

      argument :uri, :string, allow_nil?: false

      run fn input, context ->
        uri = Ash.ActionInput.get_argument(input, :uri)
        actor = Map.get(context, :actor)

        # Extract photo ID from URI: vmemo://photo/{id}/html
        id = extract_photo_id_from_uri(uri)

        if is_nil(id) do
          {:error, "Invalid URI format. Expected: vmemo://photo/{id}/html"}
        else
          case Ash.get(__MODULE__, id, actor: actor) do
            {:ok, photo} ->
              normalized_photo = normalize_photo_url_for_api(photo)
              base_url = get_base_url()

              full_url =
                if String.starts_with?(normalized_photo.url, "http"),
                  do: normalized_photo.url,
                  else: base_url <> normalized_photo.url

              {:safe, alt_text} =
                Phoenix.HTML.html_escape(
                  normalized_photo.caption || normalized_photo.note || "Photo"
                )

              caption_html =
                if normalized_photo.caption do
                  {:safe, escaped_caption} = Phoenix.HTML.html_escape(normalized_photo.caption)
                  "<p class=\"photo-caption\">#{escaped_caption}</p>"
                else
                  ""
                end

              note_html =
                if normalized_photo.note do
                  {:safe, escaped_note} = Phoenix.HTML.html_escape(normalized_photo.note)
                  "<p class=\"photo-note\">#{escaped_note}</p>"
                else
                  ""
                end

              html = """
              <div class="photo-card">
                <img src="#{full_url}" alt="#{alt_text}" class="photo-image" />
                #{caption_html}
                #{note_html}
              </div>
              """

              {:ok, html}

            {:error, reason} ->
              {:error, reason}
          end
        end
      end
    end

    # MCP Resource action: Return photo as image (base64 encoded)
    # URI format: vmemo://photo/{id}/image
    # The id will be extracted from the URI and passed as a parameter
    action :get_photo_image, :string do
      description "Get a photo as base64-encoded image data. Returns the image data in data URL format (data:image/{type};base64,...). The MIME type is auto-detected from file content (supports JPEG, PNG, GIF, WEBP)."

      argument :uri, :string, allow_nil?: false

      run fn input, context ->
        uri = Ash.ActionInput.get_argument(input, :uri)
        actor = Map.get(context, :actor)

        # Extract photo ID from URI: vmemo://photo/{id}/image
        id = extract_photo_id_from_uri(uri)

        if is_nil(id) do
          {:error, "Invalid URI format. Expected: vmemo://photo/{id}/image"}
        else
          case Ash.get(__MODULE__, id, actor: actor) do
            {:ok, photo} ->
              normalized_photo = normalize_photo_url_for_api(photo)

              case read_image_as_base64(normalized_photo.url) do
                {:ok, {base64_data, mime_type}} ->
                  # Return data URL format: data:image/jpeg;base64,<base64_data>
                  {:ok, "data:#{mime_type};base64,#{base64_data}"}

                {:error, reason} ->
                  {:error, "Failed to read image: #{inspect(reason)}"}
              end

            {:error, reason} ->
              {:error, reason}
          end
        end
      end
    end

    # Helper function to extract photo ID from URI
    defp extract_photo_id_from_uri(uri) do
      # Match pattern: vmemo://photo/{uuid}/url or vmemo://photo/{uuid}/html or vmemo://photo/{uuid}/image
      regex =
        ~r/vmemo:\/\/photo\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/(url|html|image)/

      case Regex.run(regex, uri) do
        [_, id, _] -> id
        _ -> nil
      end
    end

    # Helper function to read image file as base64 with MIME type detection
    defp read_image_as_base64(url) do
      relative_path =
        url
        |> String.trim_leading("/")
        |> String.trim_leading("storage/v1/")

      file_path = Path.join(["storage", "v1", relative_path])

      case File.read(file_path) do
        {:ok, binary} ->
          mime_type = detect_mime_type_from_binary(binary) || "image/jpeg"
          base64_data = Base.encode64(binary)
          {:ok, {base64_data, mime_type}}

        {:error, :enoent} ->
          {:error, :file_not_found}

        {:error, reason} ->
          {:error, reason}
      end
    end

    # Helper function to detect MIME type from binary image data
    defp detect_mime_type_from_binary(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "image/jpeg"

    defp detect_mime_type_from_binary(
           <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>
         ),
         do: "image/png"

    defp detect_mime_type_from_binary(<<"GIF87a", _::binary>>), do: "image/gif"
    defp detect_mime_type_from_binary(<<"GIF89a", _::binary>>), do: "image/gif"

    defp detect_mime_type_from_binary(<<"RIFF", _::binary-size(4), "WEBP", _::binary>>),
      do: "image/webp"

    defp detect_mime_type_from_binary(_), do: nil

    read :list_similar do
      argument :photo_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        photo_id = Ash.Query.get_argument(query, :photo_id)
        user_id = Ash.Query.get_argument(query, :user_id)

        photos = TsPhoto.list_similar_photos(photo_id, user_id: user_id)

        photo_ids =
          photos
          |> Enum.map(& &1.id)
          |> Enum.filter(&valid_uuid?/1)

        # Load all matching photos then sort by the order from Typesense
        query
        |> Ash.Query.filter(id: [in: photo_ids])
        |> Ash.Query.after_action(fn _query, records ->
          # Sort records by the order of photo_ids from Typesense
          sorted_records =
            photo_ids
            |> Enum.map(fn id ->
              Enum.find(records, fn record -> record.id == id end)
            end)
            |> Enum.reject(&is_nil/1)

          {:ok, sorted_records}
        end)
      end
    end

    update :gen_description do
      require_atomic? false

      change fn changeset, context ->
        photo_id = Ash.Changeset.get_attribute(changeset, :id)

        case TsPhoto.gen_description(photo_id) do
          {:ok, description} ->
            Ash.Changeset.change_attribute(changeset, :caption, description)

          {:error, reason} ->
            Ash.Changeset.add_error(changeset,
              field: :base,
              message: "Failed to generate description: #{inspect(reason)}"
            )
        end
      end

      change run_oban_trigger(:sync_typesense)
    end
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :url, :string do
      allow_nil? false
    end

    attribute :note, :string
    attribute :caption, :string
    attribute :ts_ocr, :string
    attribute :file_id, :string
    attribute :user_id, :uuid

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :notes, Vmemo.Photos.Note do
      through Vmemo.Photos.PhotoNote
      source_attribute_on_join_resource :photo_id
      destination_attribute_on_join_resource :note_id
    end
  end

  # Normalize photo URL for API responses (used in search_photos action)
  defp normalize_photo_url_for_api(photo) do
    base_url = get_base_url()

    normalized_url =
      cond do
        # If URL is already absolute with wrong domain, extract path and rebuild
        String.starts_with?(photo.url, "https://example.com") ->
          path = String.replace_prefix(photo.url, "https://example.com", "")
          base_url <> path

        String.starts_with?(photo.url, "http://example.com") ->
          path = String.replace_prefix(photo.url, "http://example.com", "")
          base_url <> path

        # If URL is already absolute with correct domain, keep as is
        String.starts_with?(photo.url, "http://") or String.starts_with?(photo.url, "https://") ->
          photo.url

        # Relative path, convert to absolute URL
        true ->
          base_url <> photo.url
      end

    # Update the photo struct with normalized URL
    %{photo | url: normalized_url}
  end

  defp get_base_url do
    if Mix.env() == :prod do
      host = System.get_env("PHX_HOST") || "vmemo.app"
      "https://#{host}"
    else
      "http://localhost:4000"
    end
  end

  defp typesense_hybrid_search(q, similar, user_id, page) do
    TsPhoto.hybird_search_photos({q, similar},
      user_id: user_id,
      page: page
    )
  end

  defp upsert_typesense_photo(photo) do
    typesense_data = build_typesense_sync_payload(photo)

    case TsPhoto.get_photo(photo.id) do
      nil -> sync_photo_with_typesense_retry(typesense_data, :create)
      {:error, reason} -> {:error, reason}
      _existing -> sync_photo_with_typesense_retry(typesense_data, :update)
    end
  end

  defp sync_photo_with_typesense_retry(typesense_data, :create) do
    case TsPhoto.create(typesense_data) do
      {:error, "Not Found"} ->
        with :ok <- migrate_typesense_schema(),
             {:ok, created} <- TsPhoto.create(typesense_data) do
          {:ok, created}
        end

      result ->
        result
    end
  end

  defp sync_photo_with_typesense_retry(typesense_data, :update) do
    case TsPhoto.update_photo(typesense_data) do
      {:error, "Not Found"} ->
        with :ok <- migrate_typesense_schema(),
             {:ok, _updated} <- sync_photo_after_migration(typesense_data) do
          {:ok, true}
        end

      {:ok, updated} ->
        {:ok, updated}

      error ->
        error
    end
  end

  defp sync_photo_after_migration(typesense_data) do
    case TsPhoto.update_photo(typesense_data) do
      {:error, "Not Found"} -> TsPhoto.create(typesense_data)
      result -> result
    end
  end

  defp migrate_typesense_schema do
    try do
      case Vmemo.Ts.migrate() do
        :ok -> :ok
        other -> {:error, "Typesense migration failed: #{inspect(other)}"}
      end
    rescue
      exception ->
        {:error, "Typesense migration failed: #{Exception.message(exception)}"}
    end
  end

  defp build_typesense_sync_payload(photo) do
    base_payload = %{
      id: photo.id,
      note: photo.note || "",
      caption: photo.caption || "",
      note_ids: Enum.map(photo.notes || [], & &1.id),
      url: photo.url,
      file_id: photo.file_id,
      inserted_at: to_unix_timestamp(photo.inserted_at),
      inserted_by: photo.user_id,
      _gen_ocr: photo.ts_ocr
    }

    case read_image_base64_for_typesense(photo.url) do
      {:ok, image} -> Map.put(base_payload, :image, image)
      _ -> base_payload
    end
  end

  defp read_image_base64_for_typesense(url) do
    case read_image_as_base64(url) do
      {:ok, {base64_data, _mime_type}} -> {:ok, base64_data}
      {:error, reason} -> {:error, reason}
    end
  end

  defp to_unix_timestamp(%NaiveDateTime{} = naive_dt) do
    naive_dt
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end

  defp to_unix_timestamp(%DateTime{} = date_time), do: DateTime.to_unix(date_time)
  defp to_unix_timestamp(_), do: :os.system_time(:second)

  defp blank_query_without_similar?(q, similar) do
    String.trim(to_string(q || "")) == "" and String.trim(to_string(similar || "")) == ""
  end

  defp generate_caption_for_photo(photo) do
    if is_nil(photo.caption) or photo.caption == "" do
      RLS.with_bypass(fn ->
        with {:ok, image_base64} <- read_image_base64_for_typesense(photo.url),
             {:ok, caption} <- Moondream.caption(image_base64),
             {:ok, _updated_photo} <-
               __MODULE__.update(photo, %{caption: caption}, actor: nil, authorize?: false) do
          :ok
        else
          {:error, :file_not_found} ->
            :ok

          {:error, reason} ->
            {:error, reason}
        end
      end)
    else
      :ok
    end
  end
end
