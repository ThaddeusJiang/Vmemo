defmodule Vmemo.Repo.Migrations.AddTagTables do
  use Ecto.Migration

  def change do
    create table(:memo_tags, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:memo_tags, [:name], name: "memo_tags_unique_name_index")

    create table(:memo_images_tags, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :image_id,
          references(:memo_images,
            column: :id,
            name: "memo_images_tags_image_id_fkey",
            type: :uuid,
            on_delete: :delete_all
          ),
          null: false

      add :tag_id,
          references(:memo_tags,
            column: :id,
            name: "memo_images_tags_tag_id_fkey",
            type: :uuid,
            on_delete: :delete_all
          ),
          null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:memo_images_tags, [:image_id, :tag_id],
             name: "memo_images_tags_unique_image_tag_pair_index"
           )
  end
end
