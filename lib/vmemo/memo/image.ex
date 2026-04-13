defmodule Vmemo.Memo.Image do
  @moduledoc false
  @derive {Jason.Encoder,
           only: [
             :id,
             :url,
             :note,
             :caption,
             :typesense_status,
             :moondream_status,
             :file_id,
             :user_id,
             :inserted_at,
             :updated_at
           ]}
  use Ash.Resource,
    domain: Vmemo.Memo,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource, AshOban]

  require Ash.Query
  require Logger

  alias Vmemo.Ai.Caption
  alias Vmemo.Memo.ImageStorage
  alias Vmemo.SearchEngine.TsImage

  postgres do
    table "memo_images"
    repo Vmemo.Repo
  end

  admin do
    table_columns([
      :id,
      :url,
      :note,
      :caption,
      :typesense_status,
      :moondream_status,
      :inner_purpose,
      :user_id,
      :inserted_at
    ])
  end

  oban do
    triggers do
      trigger :sync_typesense do
        action :sync_typesense
        queue :sync_typesense
        lock_for_update? false
        scheduler_cron false
        where expr(true)
        worker_module_name Vmemo.Memo.Image.Workers.SyncTypesense
        scheduler_module_name Vmemo.Memo.Image.Schedulers.SyncTypesense
      end

      trigger :generate_caption do
        action :generate_caption
        queue :ai_vision
        max_attempts 5
        scheduler_cron false
        where expr(true)
        worker_module_name Vmemo.Memo.Image.Workers.GenerateCaption
        scheduler_module_name Vmemo.Memo.Image.Schedulers.GenerateCaption
      end
    end
  end

  code_interface do
    define :create_with_sync
    define :create_for_image_search
    define :create_immediate
    define :read
    define :update
    define :destroy
    define :get_with_notes, args: [:id, :user_id]
    define :hybrid_search, args: [:query, :similar_image_id, :user_id, :page]
    define :hybrid_search_count, args: [:query, :similar_image_id, :user_id]
    define :library_images_count, args: [:user_id]
    define :list_similar, args: [:image_id, :user_id]
    define :sync_typesense_by_id, args: [:image_id]
    define :ingest_temp_file_for_similarity_search, args: [:temp_path, :storage_file_id]
    define :update_search_engine
    define :request_generate_caption
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
      accept [:url, :note, :caption, :file_id, :user_id]
    end

    @doc """
    Persist row for search-by-image without Oban. Used by `ingest_temp_file_for_similarity_search/2`.

    Moondream caption jobs are upload-only; this action leaves `moondream_status` at the resource default.
    """
    create :create_for_image_search do
      accept [:url, :note, :caption, :file_id, :user_id, :inner_purpose]
      change set_attribute(:typesense_status, "pending")
    end

    create :import do
      accept [:id, :url, :note, :caption, :file_id, :user_id, :inner_purpose]
    end

    create :create_with_sync do
      accept [:url, :note, :caption, :file_id, :user_id, :inner_purpose]
      change set_attribute(:typesense_status, "pending")
      change set_attribute(:moondream_status, "pending")
      change run_oban_trigger(:sync_typesense)
      change run_oban_trigger(:generate_caption)
    end

    update :update do
      accept [:note, :caption, :url]
      require_atomic? false
      change set_attribute(:typesense_status, "pending")
      change run_oban_trigger(:sync_typesense)
    end

    update :sync_typesense do
      accept []
      require_atomic? false
      transaction? false
      change set_attribute(:typesense_status, "processing")
      change {Vmemo.Memo.Changes.SyncTypesense, resource: __MODULE__}
    end

    update :generate_caption do
      accept []
      require_atomic? false
      transaction? false
      change set_attribute(:moondream_status, "processing")

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn _changeset, record ->
          case generate_caption_for_photo(record) do
            :ok ->
              set_moondream_status(record, "completed")
              {:ok, record}

            {:discard, _reason} ->
              set_moondream_status(record, "failed")
              {:ok, record}

            {:error, reason} ->
              set_moondream_status(record, "failed")
              {:error, reason}
          end
        end)
      end
    end

    update :update_search_engine do
      accept []
      require_atomic? false
      change set_attribute(:typesense_status, "pending")
      change run_oban_trigger(:sync_typesense)
    end

    update :request_generate_caption do
      accept []
      require_atomic? false
      change set_attribute(:moondream_status, "pending")
      change run_oban_trigger(:generate_caption)
    end

    update :set_typesense_status do
      accept [:typesense_status]
      require_atomic? false
    end

    update :set_moondream_status do
      accept [:moondream_status]
      require_atomic? false
    end

    action :sync_typesense_by_id, :boolean do
      argument :image_id, :uuid, allow_nil?: false

      run fn input, _context ->
        image_id = Ash.ActionInput.get_argument(input, :image_id)

        with {:ok, image} <- Ash.get(__MODULE__, image_id, actor: nil, authorize?: false),
             {:ok, photo_with_notes} <- Ash.load(image, :notes, actor: nil, authorize?: false),
             {:ok, _} <- upsert_typesense_photo(photo_with_notes) do
          {:ok, true}
        end
      end
    end

    action :ingest_temp_file_for_similarity_search, :uuid do
      description """
      Copy a temp upload into storage, create a image row (no Oban), sync Typesense inline,
      then mark typesense_status completed. For LiveView search-by-image and similar entry points.
      """

      argument :temp_path, :string, allow_nil?: false
      argument :storage_file_id, :string, allow_nil?: false

      run fn input, context ->
        actor = Map.get(context, :actor)

        if is_nil(actor) do
          {:error, "Actor is required for ingest_temp_file_for_similarity_search"}
        else
          temp_path = Ash.ActionInput.get_argument(input, :temp_path)
          storage_file_id = Ash.ActionInput.get_argument(input, :storage_file_id)
          user_id = actor.id

          case ImageStorage.cp_file(temp_path, user_id, storage_file_id) do
            {:ok, dest} ->
              case Ash.create(
                     __MODULE__,
                     %{
                       note: "",
                       url: Path.join("/", dest),
                       file_id: storage_file_id,
                       user_id: user_id,
                       inner_purpose: "search"
                     },
                     action: :create_for_image_search,
                     actor: actor
                   ) do
                {:ok, image} ->
                  case __MODULE__.sync_typesense_by_id(image.id, actor: nil, authorize?: false) do
                    {:ok, true} ->
                      case Ash.update(image, %{typesense_status: "completed"},
                             action: :set_typesense_status,
                             actor: actor
                           ) do
                        {:ok, image} ->
                          {:ok, image.id}

                        {:error, reason} = err ->
                          rollback_ingest_search_anchor(image, actor)

                          Logger.error(
                            "ingest_temp_file_for_similarity_search failed: #{inspect(reason)}"
                          )

                          err
                      end

                    {:error, reason} = err ->
                      rollback_ingest_search_anchor(image, actor)

                      Logger.error(
                        "ingest_temp_file_for_similarity_search failed: #{inspect(reason)}"
                      )

                      err

                    other ->
                      rollback_ingest_search_anchor(image, actor)

                      Logger.error(
                        "ingest_temp_file_for_similarity_search unexpected: #{inspect(other)}"
                      )

                      {:error, other}
                  end

                {:error, reason} = err ->
                  Logger.error(
                    "ingest_temp_file_for_similarity_search failed: #{inspect(reason)}"
                  )

                  err
              end

            {:error, reason} = err ->
              Logger.error("ingest_temp_file_for_similarity_search failed: #{inspect(reason)}")
              err
          end
        end
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
      argument :similar_image_id, :string, allow_nil?: true
      argument :user_id, :uuid, allow_nil?: false
      argument :page, :integer, default: 1

      prepare fn query, _context ->
        q = Ash.Query.get_argument(query, :query) || ""
        similar = Ash.Query.get_argument(query, :similar_image_id)
        user_id = Ash.Query.get_argument(query, :user_id)
        page = Ash.Query.get_argument(query, :page)

        if blank_query_without_similar?(q, similar) do
          per_page = 10
          offset = (page - 1) * per_page

          query
          |> filter_library_photos(user_id)
          |> Ash.Query.sort(inserted_at: :desc)
          |> Ash.Query.offset(offset)
          |> Ash.Query.limit(per_page)
        else
          {images, _found, _current_page} =
            typesense_hybrid_search(q, similar, user_id, page)

          image_ids =
            images
            |> Enum.map(& &1.id)
            |> Enum.filter(&valid_uuid?/1)

          if image_ids == [] do
            Ash.Query.filter(query, id: [in: []])
          else
            query
            |> Ash.Query.filter(id: [in: image_ids])
            |> Ash.Query.after_action(fn _query, records ->
              photos_by_id = Map.new(images, fn image -> {image.id, image} end)

              sorted_records =
                image_ids
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
      argument :similar_image_id, :string, allow_nil?: true
      argument :user_id, :uuid, allow_nil?: false

      run fn input, context ->
        q = Ash.ActionInput.get_argument(input, :query) || ""
        similar = Ash.ActionInput.get_argument(input, :similar_image_id)
        user_id = Ash.ActionInput.get_argument(input, :user_id)

        if blank_query_without_similar?(q, similar) do
          __MODULE__
          |> filter_library_photos(user_id)
          |> Ash.count(actor: context.actor)
        else
          {_photos, found, _current_page} =
            typesense_hybrid_search(q, similar, user_id, 1)

          {:ok, found}
        end
      end
    end

    action :library_images_count, :integer do
      argument :user_id, :uuid, allow_nil?: false

      run fn input, context ->
        user_id = Ash.ActionInput.get_argument(input, :user_id)

        __MODULE__
        |> filter_library_photos(user_id)
        |> Ash.count(actor: context.actor)
      end
    end

    action :search_images, :string do
      description "Search images by text query or find similar images. Returns JSON array of image data URLs (data:image/{type};base64,...) for direct image display."

      argument :query, :string, default: ""
      argument :similar_image_id, :string, allow_nil?: true
      argument :page, :integer, default: 1

      run fn input, context ->
        q = Ash.ActionInput.get_argument(input, :query) || ""
        similar = Ash.ActionInput.get_argument(input, :similar_image_id)
        page = Ash.ActionInput.get_argument(input, :page) || 1

        # Get actor from context
        actor = Map.get(context, :actor)
        user_id = if actor, do: actor.id, else: nil

        if is_nil(user_id) do
          {:error, "Actor is required for image search"}
        else
          {images, _found, _current_page} =
            TsImage.hybrid_search_images({q, similar},
              user_id: user_id,
              page: page
            )

          image_ids =
            images
            |> Enum.map(& &1.id)
            |> Enum.filter(&valid_uuid?/1)

          if image_ids == [] do
            {:ok, Jason.encode!([])}
          else
            query =
              __MODULE__
              |> Ash.Query.filter(id: [in: image_ids])

            case Ash.read(query, actor: actor) do
              {:ok, records} ->
                sorted_records =
                  image_ids
                  |> Enum.map(fn id ->
                    Enum.find(records, fn record -> record.id == id end)
                  end)
                  |> Enum.reject(&is_nil/1)
                  |> Enum.map(&normalize_image_url_for_api/1)

                image_data_urls =
                  sorted_records
                  |> Enum.map(fn image ->
                    case read_image_as_base64(image.url) do
                      {:ok, {base64_data, mime_type}} ->
                        "data:#{mime_type};base64,#{base64_data}"

                      {:error, _reason} ->
                        # Fallback to URL if image read fails
                        image.url
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

    # MCP Resource action: Return image URL as string
    # URI format: vmemo://image/{id}/url
    # The id will be extracted from the URI and passed as a parameter
    action :get_image_url, :string do
      description "Get the URL of an image by ID. Returns the image URL as a string."

      argument :uri, :string, allow_nil?: false

      run fn input, context ->
        uri = Ash.ActionInput.get_argument(input, :uri)
        actor = Map.get(context, :actor)

        # Extract image ID from URI: vmemo://image/{id}/url
        id = extract_image_id_from_uri(uri)

        if is_nil(id) do
          {:error, "Invalid URI format. Expected: vmemo://image/{id}/url"}
        else
          case Ash.get(__MODULE__, id, actor: actor) do
            {:ok, image} ->
              normalized_photo = normalize_image_url_for_api(image)
              {:ok, normalized_photo.url}

            {:error, reason} ->
              {:error, reason}
          end
        end
      end
    end

    # MCP Resource action: Return image as HTML
    # URI format: vmemo://image/{id}/html
    # The id will be extracted from the URI and passed as a parameter
    action :get_image_html, :string do
      description "Get an image as HTML. Returns an HTML img tag with the image URL, caption, and note."

      argument :uri, :string, allow_nil?: false

      run fn input, context ->
        uri = Ash.ActionInput.get_argument(input, :uri)
        actor = Map.get(context, :actor)

        # Extract image ID from URI: vmemo://image/{id}/html
        id = extract_image_id_from_uri(uri)

        if is_nil(id) do
          {:error, "Invalid URI format. Expected: vmemo://image/{id}/html"}
        else
          case Ash.get(__MODULE__, id, actor: actor) do
            {:ok, image} ->
              normalized_photo = normalize_image_url_for_api(image)
              base_url = get_base_url()

              full_url =
                if String.starts_with?(normalized_photo.url, "http"),
                  do: normalized_photo.url,
                  else: base_url <> normalized_photo.url

              {:safe, alt_text} =
                Phoenix.HTML.html_escape(
                  normalized_photo.caption || normalized_photo.note || "Image"
                )

              caption_html =
                if normalized_photo.caption do
                  {:safe, escaped_caption} = Phoenix.HTML.html_escape(normalized_photo.caption)
                  "<p class=\"image-caption\">#{escaped_caption}</p>"
                else
                  ""
                end

              note_html =
                if normalized_photo.note do
                  {:safe, escaped_note} = Phoenix.HTML.html_escape(normalized_photo.note)
                  "<p class=\"image-note\">#{escaped_note}</p>"
                else
                  ""
                end

              html = """
              <div class="image-card">
                <img src="#{full_url}" alt="#{alt_text}" class="image-image" />
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

    # MCP Resource action: Return image as base64 data
    # URI format: vmemo://image/{id}/image
    # The id will be extracted from the URI and passed as a parameter
    action :get_image_data, :string do
      description "Get an image as base64-encoded image data. Returns the image data in data URL format (data:image/{type};base64,...). The MIME type is auto-detected from file content (supports JPEG, PNG, GIF, WEBP)."

      argument :uri, :string, allow_nil?: false

      run fn input, context ->
        uri = Ash.ActionInput.get_argument(input, :uri)
        actor = Map.get(context, :actor)

        # Extract image ID from URI: vmemo://image/{id}/image
        id = extract_image_id_from_uri(uri)

        if is_nil(id) do
          {:error, "Invalid URI format. Expected: vmemo://image/{id}/image"}
        else
          case Ash.get(__MODULE__, id, actor: actor) do
            {:ok, image} ->
              normalized_photo = normalize_image_url_for_api(image)

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

    # Helper function to extract image ID from URI
    defp extract_image_id_from_uri(uri) do
      # Match pattern: vmemo://image/{uuid}/url or vmemo://image/{uuid}/html or vmemo://image/{uuid}/image
      regex =
        ~r/vmemo:\/\/image\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/(url|html|image)/

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
      argument :image_id, :uuid, allow_nil?: false
      argument :user_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        image_id = Ash.Query.get_argument(query, :image_id)
        user_id = Ash.Query.get_argument(query, :user_id)

        images = TsImage.list_similar_images(image_id, user_id: user_id)

        image_ids =
          images
          |> Enum.map(& &1.id)
          |> Enum.filter(&valid_uuid?/1)

        # Load all matching images then sort by the order from Typesense
        query
        |> Ash.Query.filter(id: [in: image_ids])
        |> Ash.Query.after_action(fn _query, records ->
          # Sort records by the order of image_ids from Typesense
          sorted_records =
            image_ids
            |> Enum.map(fn id ->
              Enum.find(records, fn record -> record.id == id end)
            end)
            |> Enum.reject(&is_nil/1)

          {:ok, sorted_records}
        end)
      end
    end
  end

  validations do
    validate fn changeset, _context ->
               status = Ash.Changeset.get_attribute(changeset, :typesense_status)

               if status && status not in ["pending", "processing", "completed", "failed"] do
                 {:error,
                  field: :typesense_status,
                  message: "must be one of: pending, processing, completed, failed"}
               else
                 :ok
               end
             end,
             on: [:create, :update]

    validate fn changeset, _context ->
               status = Ash.Changeset.get_attribute(changeset, :moondream_status)

               if status && status not in ["pending", "processing", "completed", "failed"] do
                 {:error,
                  field: :moondream_status,
                  message: "must be one of: pending, processing, completed, failed"}
               else
                 :ok
               end
             end,
             on: [:create, :update]
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :url, :string do
      allow_nil? false
    end

    attribute :note, :string
    attribute :caption, :string
    attribute :typesense_status, :string, allow_nil?: false, default: "completed"
    attribute :moondream_status, :string, allow_nil?: false, default: "completed"

    attribute :inner_purpose, :string,
      allow_nil?: true,
      public?: false,
      source: :_purpose

    attribute :file_id, :string
    attribute :user_id, :uuid

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :notes, Vmemo.Memo.Note do
      through Vmemo.Memo.ImageNote
      source_attribute_on_join_resource :image_id
      destination_attribute_on_join_resource :note_id
    end
  end

  # Normalize image URL for API responses (used in search_images action)
  defp normalize_image_url_for_api(image) do
    base_url = get_base_url()

    normalized_url =
      cond do
        # If URL is already absolute with wrong domain, extract path and rebuild
        String.starts_with?(image.url, "https://example.com") ->
          path = String.replace_prefix(image.url, "https://example.com", "")
          base_url <> path

        String.starts_with?(image.url, "http://example.com") ->
          path = String.replace_prefix(image.url, "http://example.com", "")
          base_url <> path

        # If URL is already absolute with correct domain, keep as is
        String.starts_with?(image.url, "http://") or String.starts_with?(image.url, "https://") ->
          image.url

        # Relative path, convert to absolute URL
        true ->
          base_url <> image.url
      end

    # Update the image struct with normalized URL
    %{image | url: normalized_url}
  end

  defp get_base_url do
    endpoint_config = Application.get_env(:vmemo, VmemoWeb.Endpoint, [])
    url_config = Keyword.get(endpoint_config, :url, [])

    host = Keyword.get(url_config, :host)
    scheme = Keyword.get(url_config, :scheme, "http")
    port = Keyword.get(url_config, :port)

    cond do
      is_binary(host) and host != "" ->
        build_url(scheme, host, port)

      phx_host = System.get_env("PHX_HOST") ->
        "https://#{phx_host}"

      true ->
        "http://localhost:4000"
    end
  end

  defp build_url(scheme, host, port) do
    case {scheme, port} do
      {"http", 80} -> "#{scheme}://#{host}"
      {"https", 443} -> "#{scheme}://#{host}"
      {_, nil} -> "#{scheme}://#{host}"
      _ -> "#{scheme}://#{host}:#{port}"
    end
  end

  defp typesense_hybrid_search(q, similar, user_id, page) do
    TsImage.hybrid_search_images({q, similar},
      user_id: user_id,
      page: page
    )
  end

  defp upsert_typesense_photo(image) do
    typesense_data = build_typesense_sync_payload(image)

    case TsImage.get_image(image.id) do
      nil -> sync_photo_with_typesense_retry(typesense_data, :create)
      {:error, reason} -> {:error, reason}
      _existing -> sync_photo_with_typesense_retry(typesense_data, :update)
    end
  end

  defp sync_photo_with_typesense_retry(typesense_data, :create) do
    case TsImage.create(typesense_data) do
      {:error, "Not Found"} ->
        {:error, "Typesense collection not found. Please run `mix ts.migrate` first."}

      result ->
        result
    end
  end

  defp sync_photo_with_typesense_retry(typesense_data, :update) do
    case TsImage.update_image(typesense_data) do
      {:error, "Not Found"} ->
        case TsImage.create(typesense_data) do
          {:ok, _created} -> {:ok, true}
          error -> error
        end

      {:ok, updated} ->
        {:ok, updated}
    end
  end

  defp build_typesense_sync_payload(image) do
    base_payload =
      %{
        id: image.id,
        note: image.note || "",
        caption: image.caption || "",
        note_ids: Enum.map(image.notes || [], & &1.id),
        url: image.url,
        file_id: image.file_id,
        inserted_at: to_unix_timestamp(image.inserted_at),
        inserted_by: image.user_id
      }
      |> maybe_put_purpose(image.inner_purpose)

    case read_image_base64_for_typesense(image.url) do
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

  defp rollback_ingest_search_anchor(image, actor) do
    _ = TsImage.delete_image(image.id)

    case Ash.destroy(image, actor: actor) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("rollback_ingest_search_anchor destroy failed: #{inspect(reason)}")
    end
  end

  defp blank_query_without_similar?(q, similar) do
    String.trim(to_string(q || "")) == "" and String.trim(to_string(similar || "")) == ""
  end

  defp filter_library_photos(query, user_id) do
    Ash.Query.filter(
      query,
      user_id == ^user_id and (is_nil(inner_purpose) or inner_purpose != "search")
    )
  end

  defp maybe_put_purpose(payload, value) when is_binary(value),
    do: Map.put(payload, :_purpose, value)

  defp maybe_put_purpose(payload, _), do: payload

  defp generate_caption_for_photo(image) do
    cond do
      has_caption?(image.caption) -> :ok
      true -> do_generate_caption(image)
    end
  end

  defp do_generate_caption(image) do
    with {:ok, {image_base64, _mime_type}} <- read_image_as_base64(image.url),
         {:ok, caption} <- Caption.generate_caption(image_base64),
         {:ok, _updated_photo} <-
           __MODULE__.update(image, %{caption: caption}, actor: nil, authorize?: false) do
      :ok
    else
      {:error, :file_not_found} ->
        :ok

      error ->
        error
    end
  end

  defp has_caption?(caption), do: is_binary(caption) and caption != ""

  defp set_moondream_status(image, status) do
    set_job_status(image, :set_moondream_status, :moondream_status, status)
  end

  defp set_job_status(image, action, field, status) do
    changeset =
      image
      |> Ash.Changeset.for_update(
        action,
        %{field => status},
        actor: nil,
        authorize?: false
      )

    Ash.update(changeset, actor: nil, authorize?: false)
    :ok
  rescue
    _ -> :ok
  end
end
