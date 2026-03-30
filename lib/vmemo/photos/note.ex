defmodule Vmemo.Photos.Note do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  require Logger
  alias Vmemo.PhotoService.TsNote

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
    define :sync_typesense_by_id, args: [:note_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create_with_sync do
      accept [:text, :ash_user_id]

      change after_action(fn _changeset, record, _context ->
               enqueue_note_sync_job(record.id)
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
               enqueue_note_sync_job(record.id)
               {:ok, record}
             end)
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

  defp upsert_typesense_note(note) do
    typesense_data = %{
      id: note.id,
      text: note.text,
      belongs_to: note.ash_user_id,
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

  defp enqueue_note_sync_job(note_id) do
    case %{note_id: note_id}
         |> Vmemo.Workers.SyncNoteToTypesense.new()
         |> Oban.insert() do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to enqueue SyncNoteToTypesense for note #{note_id}: #{inspect(reason)}"
        )

        :error
    end
  end
end
