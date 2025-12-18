defmodule Vmemo.Photos.PhotoMoondreamRequest do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  require Ash.Query

  postgres do
    table "photo_moondream_requests"
    repo Vmemo.AshRepo
  end

  admin do
    table_columns([:id, :photo_id, :ash_user_id, :function_type, :status, :inserted_at])
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
      accept [:photo_id, :ash_user_id, :function_type, :prompt]
      change set_attribute(:status, "pending")
    end

    update :update do
      accept [:status, :result, :error_message]
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
               function_type = Ash.Changeset.get_attribute(changeset, :function_type)

               if function_type &&
                    function_type not in ["query", "caption", "point", "detect", "segment"] do
                 {:error,
                  field: :function_type,
                  message: "must be one of: query, caption, point, detect, segment"}
               else
                 :ok
               end
             end,
             on: [:create, :update]

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

    attribute :function_type, :string do
      allow_nil? false
    end

    attribute :prompt, :string

    attribute :result, :map do
      allow_nil? true
    end

    attribute :status, :string do
      allow_nil? false
      default "pending"
    end

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
