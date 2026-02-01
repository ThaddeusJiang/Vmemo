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
    create_actions([:import])

    form do
      field :import_zip do
        max_file_size 1024 * 1024 * 1024
        accepted_extensions [".zip", "application/zip"]
      end
    end
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

    create :import do
      accept [:metadata]
      argument :import_zip, Ash.Type.File, allow_nil?: false
      change set_attribute(:status, "pending")
      require_atomic? false

      change fn changeset, _context ->
        with %Ash.Type.File{} = file <- Ash.Changeset.get_argument(changeset, :import_zip),
             {:ok, path} <- Ash.Type.File.path(file) do
          filename = Path.basename(path)
          dest_dir = Path.join(System.tmp_dir!(), "vmemo-import-upload")
          File.mkdir_p!(dest_dir)
          dest_path = Path.join(dest_dir, "#{System.unique_integer([:positive])}-#{filename}")
          File.cp!(path, dest_path)

          changeset
          |> Ash.Changeset.change_attribute(:source_filename, filename)
          |> Ash.Changeset.put_context(:import_zip_path, dest_path)
        else
          _ ->
            Ash.Changeset.add_error(changeset,
              field: :import_zip,
              message: "Failed to read uploaded ZIP file"
            )
        end
      end

      change after_action(fn changeset, record, _context ->
               case changeset.context[:import_zip_path] do
                 nil ->
                   {:ok, record}

                 zip_path ->
                   %{request_id: record.id, zip_path: zip_path}
                   |> Vmemo.Workers.ProcessImportRequest.new()
                   |> Oban.insert()
                   |> case do
                     {:ok, _job} -> {:ok, record}
                     {:error, error} -> {:error, error}
                   end
               end
             end)
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
