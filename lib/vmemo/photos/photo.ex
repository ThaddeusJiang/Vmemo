defmodule Vmemo.Photos.Photo do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("photos")
    repo(Vmemo.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :url, :string do
      allow_nil?(false)
    end

    attribute(:note, :string)
    attribute(:file_id, :string)
    attribute(:image, :string)
    attribute(:user_id, :string)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    many_to_many :notes, Vmemo.Photos.Note do
      through(Vmemo.Photos.PhotoNote)
      source_attribute_on_join_resource(:photo_id)
      destination_attribute_on_join_resource(:note_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:url, :note, :file_id, :image, :user_id])

      change(
        after_action(fn _changeset, record, _context ->
          %{photo_id: record.id}
          |> Vmemo.Workers.SyncPhotoToTypesense.new()
          |> Oban.insert()

          {:ok, record}
        end)
      )
    end

    update :update do
      accept([:note, :url, :image])
      require_atomic?(false)

      change(
        after_action(fn _changeset, record, _context ->
          %{photo_id: record.id}
          |> Vmemo.Workers.SyncPhotoToTypesense.new()
          |> Oban.insert()

          {:ok, record}
        end)
      )
    end
  end

  code_interface do
    define(:create)
    define(:read)
    define(:update)
    define(:destroy)
  end
end
