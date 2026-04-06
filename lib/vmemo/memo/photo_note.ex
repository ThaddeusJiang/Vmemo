defmodule Vmemo.Memo.PhotoNote do
  @moduledoc false
  use Ash.Resource,
    domain: Vmemo.Memo,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "memo_images_notes"
    repo Vmemo.Repo
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

    create :import do
      accept [:photo_id, :note_id]
    end
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :photo, Vmemo.Memo.Photo do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :note, Vmemo.Memo.Note do
      allow_nil? false
      attribute_writable? true
    end
  end
end
