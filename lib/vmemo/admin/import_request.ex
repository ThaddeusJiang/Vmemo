defmodule Vmemo.Admin.ImportRequest do
  use Ash.Resource,
    domain: Vmemo.Admin,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "import_requests"
    repo Vmemo.AshRepo
  end

  admin do
    table_columns([:id, :status, :source_filename, :inserted_at, :updated_at])
  end

  code_interface do
    define :create
    define :read
    define :update
    define :latest
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:source_filename, :metadata]
      change set_attribute(:status, "pending")
    end

    update :update do
      accept [:status, :result, :error_message, :metadata]
      require_atomic? false
    end

    read :latest do
      prepare fn query, _context ->
        query
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.limit(1)
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
    attribute :status, :string, allow_nil?: false, default: "pending"
    attribute :source_filename, :string
    attribute :metadata, :map
    attribute :result, :map
    attribute :error_message, :string
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
