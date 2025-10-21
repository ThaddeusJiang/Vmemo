defmodule Vmemo.Photos.Note do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("notes")
    repo(Vmemo.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :text, :string do
      allow_nil?(false)
    end

    attribute(:user_id, :string)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    many_to_many :photos, Vmemo.Photos.Photo do
      through(Vmemo.Photos.PhotoNote)
      source_attribute_on_join_resource(:note_id)
      destination_attribute_on_join_resource(:photo_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:text, :user_id])

      change(
        after_action(fn _changeset, record, _context ->
          %{note_id: record.id}
          |> Vmemo.Workers.SyncNoteToTypesense.new()
          |> Oban.insert()

          {:ok, record}
        end)
      )
    end

    update :update do
      accept([:text])
      require_atomic?(false)

      change(
        after_action(fn _changeset, record, _context ->
          %{note_id: record.id}
          |> Vmemo.Workers.SyncNoteToTypesense.new()
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
