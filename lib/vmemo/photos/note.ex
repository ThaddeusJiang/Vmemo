defmodule Vmemo.Photos.Note do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource, AshOban]

  alias Vmemo.PhotoService.TsNote

  postgres do
    table "notes"
    repo Vmemo.Repo
  end

  admin do
    table_columns([:id, :text, :user_id, :inserted_at, :updated_at])
  end

  oban do
    triggers do
      trigger :sync_typesense do
        action :sync_typesense
        queue :sync_typesense
        scheduler_cron false
        where expr(true)
        worker_module_name Vmemo.Photos.Note.Workers.SyncTypesense
        scheduler_module_name Vmemo.Photos.Note.Schedulers.SyncTypesense
      end
    end
  end

  code_interface do
    define :create_with_sync
    define :read
    define :update
    define :destroy
    define :sync_typesense_by_id, args: [:note_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create_with_sync do
      accept [:text, :user_id]
      change run_oban_trigger(:sync_typesense)
    end

    create :import do
      accept [:id, :text, :user_id]
    end

    update :update do
      accept [:text]
      require_atomic? false
      change run_oban_trigger(:sync_typesense)
    end

    update :sync_typesense do
      accept []
      require_atomic? false
      transaction? false

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn _changeset, record, _context ->
          case __MODULE__.sync_typesense_by_id(record.id, actor: nil, authorize?: false) do
            {:ok, true} ->
              {:ok, record}

            {:ok, false} ->
              {:error, :sync_failed}

            {:error, reason} ->
              {:error, reason}
          end
        end)
      end
    end

    action :sync_typesense_by_id, :boolean do
      argument :note_id, :uuid, allow_nil?: false

      run fn input, _context ->
        note_id = Ash.ActionInput.get_argument(input, :note_id)

        with {:ok, note} <- Ash.get(__MODULE__, note_id, actor: nil, authorize?: false),
             {:ok, note_with_photos} <- Ash.load(note, :photos, actor: nil, authorize?: false),
             {:ok, _} <- upsert_typesense_note(note_with_photos) do
          {:ok, true}
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :text, :string do
      allow_nil? false
    end

    attribute :user_id, :uuid

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

  defp upsert_typesense_note(note) do
    typesense_data = %{
      id: note.id,
      text: note.text,
      belongs_to: note.user_id,
      photo_ids: Enum.map(note.photos || [], & &1.id),
      inserted_at: DateTime.to_unix(note.inserted_at),
      updated_at: DateTime.to_unix(note.updated_at)
    }

    case TsNote.get(note.id) do
      nil -> TsNote.create(typesense_data)
      {:error, reason} -> {:error, reason}
      _existing -> TsNote.update(typesense_data)
    end
  end
end
