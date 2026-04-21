defmodule Vmemo.Repo.Migrations.AddUserProfiles do
  use Ecto.Migration

  def change do
    create table(:auth_user_profiles, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :user_id,
          references(:auth_users,
            column: :id,
            name: "auth_user_profiles_user_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :name, :text, null: false
      add :avatar_file_id, :text
      add :language, :text, null: false, default: "en"
      add :appearance, :text, null: false, default: "system"

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:auth_user_profiles, [:user_id],
             name: "auth_user_profiles_unique_user_id"
           )
  end
end
