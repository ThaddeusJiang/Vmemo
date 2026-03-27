defmodule Vmemo.Photos.PhotoCaptionRequest do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  require Ash.Query

  postgres do
    table "photo_caption_requests"
    repo Vmemo.Repo
  end

  admin do
    table_columns([:id, :photo_id, :ash_user_id, :status, :inserted_at])
  end

  code_interface do
    define :create
    define :read
    define :update
    define :list_by_photo, args: [:photo_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:photo_id, :ash_user_id]
      change set_attribute(:status, "pending")
    end

    update :update do
      accept [:status, :caption, :error_message]
      require_atomic? false
    end

    read :list_by_photo do
      argument :photo_id, :uuid, allow_nil?: false

      filter expr(photo_id == ^arg(:photo_id))

      prepare fn query, _context ->
        Ash.Query.sort(query, inserted_at: :desc)
      end
    end
  end

  validations do
    validate fn changeset, _context ->
               status = Ash.Changeset.get_attribute(changeset, :status)

               if status && status not in ["pending", "processing", "completed", "failed"] do
                 {:error,
                  field: :status,
                  message: "must be one of: pending, processing, completed, failed"}
               else
                 :ok
               end
             end,
             on: [:create, :update]
  end

  attributes do
    uuid_primary_key :id

    attribute :photo_id, :uuid do
      allow_nil? false
    end

    attribute :ash_user_id, :uuid do
      allow_nil? false
    end

    attribute :status, :string do
      allow_nil? false
      default "pending"
    end

    attribute :caption, :string

    attribute :error_message, :string

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :photo, Vmemo.Photos.Photo do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :ash_user, Vmemo.Account.AshUser do
      allow_nil? false
      attribute_writable? true
      attribute_type :uuid
      domain Vmemo.AccountDomain
    end
  end
end
