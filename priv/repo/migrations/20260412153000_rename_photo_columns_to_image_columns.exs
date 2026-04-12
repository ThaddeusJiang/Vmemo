defmodule Vmemo.Repo.Migrations.RenamePhotoColumnsToImageColumns do
  use Ecto.Migration

  def up do
    if column_exists?("memo_images_notes", "photo_id") do
      rename table(:memo_images_notes), :photo_id, to: :image_id
    end

    if column_exists?("ai_vision_requests", "photo_id") do
      rename table(:ai_vision_requests), :photo_id, to: :image_id
    end

    execute("DROP INDEX IF EXISTS memo_images_notes_photo_id_note_id_index")
    execute("DROP INDEX IF EXISTS memo_images_notes_image_id_note_id_index")

    create_if_not_exists unique_index(:memo_images_notes, [:image_id, :note_id],
                           name: "memo_images_notes_image_id_note_id_index"
                         )

    execute("DROP INDEX IF EXISTS ai_vision_requests_photo_id_index")
    execute("DROP INDEX IF EXISTS ai_vision_requests_image_id_index")

    create_if_not_exists index(:ai_vision_requests, [:image_id],
                           name: "ai_vision_requests_image_id_index"
                         )

    execute(
      "ALTER TABLE memo_images_notes RENAME CONSTRAINT memo_images_notes_photo_id_fkey TO memo_images_notes_image_id_fkey",
      "ALTER TABLE memo_images_notes RENAME CONSTRAINT memo_images_notes_image_id_fkey TO memo_images_notes_photo_id_fkey"
    )

    execute(
      "ALTER TABLE ai_vision_requests RENAME CONSTRAINT ai_vision_requests_photo_id_fkey TO ai_vision_requests_image_id_fkey",
      "ALTER TABLE ai_vision_requests RENAME CONSTRAINT ai_vision_requests_image_id_fkey TO ai_vision_requests_photo_id_fkey"
    )
  end

  def down do
    execute("DROP INDEX IF EXISTS memo_images_notes_image_id_note_id_index")

    if column_exists?("memo_images_notes", "image_id") do
      rename table(:memo_images_notes), :image_id, to: :photo_id
    end

    create_if_not_exists unique_index(:memo_images_notes, [:photo_id, :note_id],
                           name: "memo_images_notes_photo_id_note_id_index"
                         )

    execute("DROP INDEX IF EXISTS ai_vision_requests_image_id_index")

    if column_exists?("ai_vision_requests", "image_id") do
      rename table(:ai_vision_requests), :image_id, to: :photo_id
    end

    create_if_not_exists index(:ai_vision_requests, [:photo_id],
                           name: "ai_vision_requests_photo_id_index"
                         )

    execute(
      "ALTER TABLE memo_images_notes RENAME CONSTRAINT memo_images_notes_image_id_fkey TO memo_images_notes_photo_id_fkey",
      "ALTER TABLE memo_images_notes RENAME CONSTRAINT memo_images_notes_photo_id_fkey TO memo_images_notes_image_id_fkey"
    )

    execute(
      "ALTER TABLE ai_vision_requests RENAME CONSTRAINT ai_vision_requests_image_id_fkey TO ai_vision_requests_photo_id_fkey",
      "ALTER TABLE ai_vision_requests RENAME CONSTRAINT ai_vision_requests_photo_id_fkey TO ai_vision_requests_image_id_fkey"
    )
  end

  defp column_exists?(table, column) do
    repo().query!(
      """
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = $1
        AND column_name = $2
      LIMIT 1
      """,
      [table, column]
    ).num_rows > 0
  end
end
