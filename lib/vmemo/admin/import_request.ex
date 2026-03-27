defmodule Vmemo.Admin.ImportRequest do
  use Ash.Resource,
    domain: Vmemo.Admin,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "import_requests"
    repo Vmemo.Repo
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
      accept []
      argument :import_zip, Ash.Type.File, allow_nil?: false
      change set_attribute(:status, "pending")

      change fn changeset, _context ->
        case persist_import_zip(changeset) do
          {:ok, filename, dest_path} ->
            changeset
            |> Ash.Changeset.change_attribute(:source_filename, filename)
            |> Ash.Changeset.put_context(:import_zip_path, dest_path)

          {:error, _reason} ->
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

  defp persist_import_zip(changeset) do
    case Ash.Changeset.get_argument(changeset, :import_zip) do
      %Ash.Type.File{} = file ->
        dest_dir = Path.join(System.tmp_dir!(), "vmemo-import-upload")
        File.mkdir_p!(dest_dir)
        copy_import_zip(file, dest_dir)

      _ ->
        {:error, :missing_file}
    end
  end

  defp copy_import_zip(file, dest_dir) do
    case Ash.Type.File.path(file) do
      {:ok, path} ->
        filename = Path.basename(path)
        dest_path = Path.join(dest_dir, "#{System.unique_integer([:positive])}-#{filename}")
        File.cp!(path, dest_path)
        {:ok, filename, dest_path}

      {:error, _reason} ->
        filename = file_source_filename(file)
        dest_path = Path.join(dest_dir, "#{System.unique_integer([:positive])}-#{filename}")

        with {:ok, source} <- Ash.Type.File.open(file, [:read, :binary]) do
          result = copy_stream(source, dest_path)
          File.close(source)

          case result do
            :ok -> {:ok, filename, dest_path}
            {:error, reason} -> {:error, reason}
          end
        else
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp copy_stream(source, dest_path) do
    File.open(dest_path, [:write, :binary], fn dest ->
      source
      |> IO.binstream(64_000)
      |> Enum.each(&IO.binwrite(dest, &1))
    end)
  end

  defp file_source_filename(%Ash.Type.File{source: %Plug.Upload{filename: filename}})
       when is_binary(filename) and filename != "" do
    filename
  end

  defp file_source_filename(%Ash.Type.File{source: path}) when is_binary(path) do
    Path.basename(path)
  end

  defp file_source_filename(_file), do: "import.zip"
end
