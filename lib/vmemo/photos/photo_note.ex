defmodule Vmemo.Photos.PhotoNote do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "photos_notes"
    repo Vmemo.AshRepo
  end

  admin do
    table_columns([:id, :photo_id, :note_id, :inserted_at])
  end

  code_interface do
    define :create
    define :read
    define :destroy
  end

  actions do
    defaults [:read, :create, :destroy]
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :photo, Vmemo.Photos.Photo do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :note, Vmemo.Photos.Note do
      allow_nil? false
      attribute_writable? true
    end
  end
end
