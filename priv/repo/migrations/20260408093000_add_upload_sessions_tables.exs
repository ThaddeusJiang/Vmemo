defmodule Vmemo.Repo.Migrations.AddUploadSessionsTables do
  use Ecto.Migration

  def change do
    create table(:memo_upload_sessions, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :user_id, :uuid, null: false
      add :note_id, :uuid
      add :client_session_key, :text, null: false
      add :status, :text, null: false, default: "pending"
      add :total_count, :bigint, null: false, default: 0
      add :completed_count, :bigint, null: false, default: 0
      add :failed_count, :bigint, null: false, default: 0
      add :last_error, :text
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:memo_upload_sessions, [:user_id, :client_session_key],
             name: :memo_upload_sessions_user_client_key_index
           )

    create index(:memo_upload_sessions, [:user_id, :status])

    create table(:memo_upload_session_items, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :upload_session_id, :uuid, null: false
      add :order_index, :bigint, null: false
      add :client_file_fingerprint, :text, null: false
      add :file_name, :text, null: false
      add :mime_type, :text
      add :size, :bigint, null: false
      add :photo_id, :uuid
      add :status, :text, null: false, default: "queued"
      add :retry_count, :bigint, null: false, default: 0
      add :last_error, :text
      timestamps(type: :utc_datetime_usec)
    end

    create index(:memo_upload_session_items, [:upload_session_id])

    create unique_index(
             :memo_upload_session_items,
             [:upload_session_id, :client_file_fingerprint],
             name: :memo_upload_session_items_session_fingerprint_index
           )
  end
end
