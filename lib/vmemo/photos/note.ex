defmodule Vmemo.Photos.Note do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "notes"
    repo Vmemo.Repo
  end

  admin do
    table_columns([:id, :text, :ash_user_id, :inserted_at, :updated_at])
  end

  code_interface do
    define :create_with_sync
    define :read
    define :update
    define :destroy
  end

  actions do
    defaults [:read, :destroy]

    create :create_with_sync do
      accept [:text, :ash_user_id]

      change after_action(fn _changeset, record, _context ->
               %{note_id: record.id}
               |> Vmemo.Workers.SyncNoteToTypesense.new()
               |> Oban.insert()

               {:ok, record}
             end)
    end

    create :import do
      accept [:id, :text, :ash_user_id]
    end

    update :update do
      accept [:text]
      require_atomic? false

      change after_action(fn _changeset, record, _context ->
               %{note_id: record.id}
               |> Vmemo.Workers.SyncNoteToTypesense.new()
               |> Oban.insert()

               {:ok, record}
             end)
    end
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :text, :string do
      allow_nil? false
    end

    attribute :ash_user_id, :uuid

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :photos, Vmemo.Photos.Photo do
      through Vmemo.Photos.PhotoNote
      source_attribute_on_join_resource :note_id
      destination_attribute_on_join_resource :photo_id
    end
  end
end
