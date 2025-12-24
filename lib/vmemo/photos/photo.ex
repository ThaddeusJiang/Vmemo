defmodule Vmemo.Photos.Photo do
  @derive {Jason.Encoder,
           only: [:id, :url, :note, :caption, :file_id, :ash_user_id, :inserted_at, :updated_at]}
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  require Ash.Query

  postgres do
    table "photos"
    repo Vmemo.AshRepo
  end

  admin do
    table_columns([:id, :url, :note, :caption, :ash_user_id, :inserted_at])
  end

  code_interface do
    define :create_with_sync
    define :create_immediate
    define :read
    define :update
    define :destroy
    define :get_with_notes, args: [:id, :ash_user_id]
    define :hybrid_search, args: [:query, :similar_photo_id, :ash_user_id, :page]
    define :list_similar, args: [:photo_id, :ash_user_id]
    define :gen_description
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
      accept [:url, :note, :caption, :file_id, :ash_user_id]
    end

    create :create_with_sync do
      accept [:url, :note, :caption, :file_id, :ash_user_id]

      change after_action(fn _changeset, record, _context ->
               %{photo_id: record.id}
               |> Vmemo.Workers.SyncPhotoToTypesense.new()
               |> Oban.insert()

               {:ok, record}
             end)
    end

    update :update do
      accept [:note, :caption, :url]
      require_atomic? false

      change after_action(fn _changeset, record, _context ->
               %{photo_id: record.id}
               |> Vmemo.Workers.SyncPhotoToTypesense.new()
               |> Oban.insert()

               {:ok, record}
             end)
    end

    read :get_with_notes do
      get? true
      argument :id, :string, allow_nil?: false
      argument :ash_user_id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id) and ash_user_id == ^arg(:ash_user_id))

      prepare fn query, _context ->
        Ash.Query.load(query, :notes)
      end
    end

    read :hybrid_search do
      argument :query, :string
      argument :similar_photo_id, :string
      argument :ash_user_id, :uuid, allow_nil?: false
      argument :page, :integer, default: 1

      prepare fn query, _context ->
        q = Ash.Query.get_argument(query, :query) || ""
        similar = Ash.Query.get_argument(query, :similar_photo_id)
        ash_user_id = Ash.Query.get_argument(query, :ash_user_id)
        page = Ash.Query.get_argument(query, :page)

        {photos, _found, _current_page} =
          Vmemo.PhotoService.TsPhoto.hybird_search_photos({q, similar},
            user_id: ash_user_id,
            page: page
          )

        photo_ids =
          photos
          |> Enum.map(& &1.id)
          |> Enum.filter(&valid_uuid?/1)

        if photo_ids == [] do
          per_page = 10
          offset = (page - 1) * per_page

          Ash.Query.filter(query, ash_user_id == ^ash_user_id)
          |> Ash.Query.sort(inserted_at: :desc)
          |> Ash.Query.offset(offset)
          |> Ash.Query.limit(per_page)
        else
          query
          |> Ash.Query.filter(id: [in: photo_ids])
          |> Ash.Query.after_action(fn _query, records ->
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
    end

    action :search_photos, :term do
      description "Search photos by text query or find similar photos. Returns HTML with photos matching the search criteria."

      argument :query, :string, default: ""
      argument :similar_photo_id, :string, allow_nil?: true
      argument :page, :integer, default: 1

      run fn input, context ->
        q = Ash.ActionInput.get_argument(input, :query) || ""
        similar = Ash.ActionInput.get_argument(input, :similar_photo_id)
        page = Ash.ActionInput.get_argument(input, :page) || 1

        # Get actor from context
        actor = Map.get(context, :actor)
        ash_user_id = if actor, do: actor.id, else: nil

        if is_nil(ash_user_id) do
          {:error, "Actor is required for photo search"}
        else
          {photos, _found, _current_page} =
            Vmemo.PhotoService.TsPhoto.hybird_search_photos({q, similar},
              user_id: ash_user_id,
              page: page
            )

          photo_ids =
            photos
            |> Enum.map(& &1.id)
            |> Enum.filter(&valid_uuid?/1)

          if photo_ids == [] do
            {:ok, "<div>No photos found.</div>"}
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

                html = render_photos_as_html(sorted_records)
                {:ok, html}

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

    # Helper function to extract photo ID from URI
    defp extract_photo_id_from_uri(uri) do
      # Match pattern: vmemo://photo/{uuid}/url or vmemo://photo/{uuid}/html
      regex =
        ~r/vmemo:\/\/photo\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/(url|html)/

      case Regex.run(regex, uri) do
        [_, id, _] -> id
        _ -> nil
      end
    end

    read :list_similar do
      argument :photo_id, :uuid, allow_nil?: false
      argument :ash_user_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        photo_id = Ash.Query.get_argument(query, :photo_id)
        ash_user_id = Ash.Query.get_argument(query, :ash_user_id)

        photos = Vmemo.PhotoService.TsPhoto.list_similar_photos(photo_id, user_id: ash_user_id)

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

        case Vmemo.PhotoService.TsPhoto.gen_description(photo_id) do
          {:ok, description} ->
            Ash.Changeset.change_attribute(changeset, :caption, description)

          {:error, reason} ->
            Ash.Changeset.add_error(changeset,
              field: :base,
              message: "Failed to generate description: #{inspect(reason)}"
            )
        end
      end

      change after_action(fn _changeset, record, _context ->
               %{photo_id: record.id}
               |> Vmemo.Workers.SyncPhotoToTypesense.new()
               |> Oban.insert()

               {:ok, record}
             end)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :url, :string do
      allow_nil? false
    end

    attribute :note, :string
    attribute :caption, :string
    attribute :file_id, :string
    attribute :ash_user_id, :uuid

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

  # Render multiple photos as HTML
  defp render_photos_as_html(photos) when is_list(photos) do
    base_url = get_base_url()

    photo_htmls =
      Enum.map(photos, fn photo ->
        full_url =
          if String.starts_with?(photo.url, "http"),
            do: photo.url,
            else: base_url <> photo.url

        {:safe, alt_text} = Phoenix.HTML.html_escape(photo.caption || photo.note || "Photo")

        caption_html =
          if photo.caption do
            {:safe, escaped_caption} = Phoenix.HTML.html_escape(photo.caption)
            "<div class=\"photo-caption\">#{escaped_caption}</div>"
          else
            ""
          end

        note_html =
          if photo.note do
            {:safe, escaped_note} = Phoenix.HTML.html_escape(photo.note)
            "<div class=\"photo-note\">#{escaped_note}</div>"
          else
            ""
          end

        """
        <div class="photo-card">
          <img src="#{full_url}" alt="#{alt_text}" class="photo-image" />
          #{caption_html}
          #{note_html}
        </div>
        """
      end)

    "<div class=\"photo-search-results\">#{Enum.join(photo_htmls, "")}</div>"
  end

  defp render_photos_as_html(_), do: "<div>No photos found.</div>"

  defp get_base_url do
    if Mix.env() == :prod do
      host = System.get_env("PHX_HOST") || "vmemo.app"
      "https://#{host}"
    else
      "http://localhost:4000"
    end
  end
end
