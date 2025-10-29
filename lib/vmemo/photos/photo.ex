defmodule Vmemo.Photos.Photo do
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
    table_columns([:id, :url, :note, :user_id, :inserted_at])
  end

  code_interface do
    define :create_with_sync
    define :read
    define :update
    define :destroy
    define :get_with_notes, args: [:id, :user_id]
    define :hybrid_search, args: [:query, :similar_photo_id, :user_id, :page]
    define :list_similar, args: [:photo_id, :user_id]
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

    create :create_with_sync do
      accept [:url, :note, :file_id, :image, :user_id]

      change after_action(fn _changeset, record, _context ->
               %{photo_id: record.id}
               |> Vmemo.Workers.SyncPhotoToTypesense.new()
               |> Oban.insert()

               {:ok, record}
             end)
    end

    update :update do
      accept [:note, :url, :image]
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
      argument :user_id, :string, allow_nil?: false

      filter expr(id == ^arg(:id) and user_id == ^arg(:user_id))

      prepare fn query, _context ->
        Ash.Query.load(query, :notes)
      end
    end

    read :hybrid_search do
      argument :query, :string
      argument :similar_photo_id, :string
      argument :user_id, :string, allow_nil?: false
      argument :page, :integer, default: 1

      prepare fn query, _context ->
        q = Ash.Query.get_argument(query, :query) || ""
        similar = Ash.Query.get_argument(query, :similar_photo_id)
        user_id = Ash.Query.get_argument(query, :user_id)
        page = Ash.Query.get_argument(query, :page)

        photos =
          Vmemo.PhotoService.TsPhoto.hybird_search_photos({q, similar},
            user_id: user_id,
            page: page
          )

        photo_ids =
          photos
          |> Enum.map(& &1.id)
          |> Enum.filter(&valid_uuid?/1)

        Ash.Query.filter(query, id: [in: photo_ids])
      end
    end

    read :list_similar do
      argument :photo_id, :uuid, allow_nil?: false
      argument :user_id, :string, allow_nil?: false

      prepare fn query, _context ->
        photo_id = Ash.Query.get_argument(query, :photo_id)
        user_id = Ash.Query.get_argument(query, :user_id)

        photos = Vmemo.PhotoService.TsPhoto.list_similar_photos(photo_id, user_id: user_id)

        photo_ids =
          photos
          |> Enum.map(& &1.id)
          |> Enum.filter(&valid_uuid?/1)

        Ash.Query.filter(query, id: [in: photo_ids])
      end
    end

    update :gen_description do
      require_atomic? false

      change fn changeset, _context ->
        photo_id = Ash.Changeset.get_attribute(changeset, :id)

        case Vmemo.PhotoService.TsPhoto.gen_description(photo_id) do
          {:ok, _} ->
            changeset

          {:error, reason} ->
            Ash.Changeset.add_error(changeset,
              field: :base,
              message: "Failed to generate description: #{reason}"
            )
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :url, :string do
      allow_nil? false
    end

    attribute :note, :string
    attribute :file_id, :string
    attribute :image, :string
    attribute :user_id, :string

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
end
