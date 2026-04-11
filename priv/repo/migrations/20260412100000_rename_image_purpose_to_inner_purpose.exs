defmodule Vmemo.Repo.Migrations.RenameImagePurposeToInnerPurpose do
  use Ecto.Migration

  def up do
    if memo_images_column?("image_purpose") do
      rename table(:memo_images), :image_purpose, to: :_purpose

      execute("""
      UPDATE memo_images
      SET _purpose = NULL
      WHERE _purpose = 'library' OR _purpose IS NULL
      """)

      execute("""
      UPDATE memo_images
      SET _purpose = 'search'
      WHERE _purpose = 'similarity_query'
      """)
    end
  end

  def down do
    if memo_images_column?("_purpose") and not memo_images_column?("image_purpose") do
      execute("""
      UPDATE memo_images
      SET _purpose = 'library'
      WHERE _purpose IS NULL OR _purpose = ''
      """)

      execute("""
      UPDATE memo_images
      SET _purpose = 'similarity_query'
      WHERE _purpose = 'search'
      """)

      rename table(:memo_images), :_purpose, to: :image_purpose
    end
  end

  defp memo_images_column?(name) when is_binary(name) do
    %{rows: [[count]]} =
      repo().query!(
        """
        SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'memo_images' AND column_name = $1
        """,
        [name]
      )

    count == 1
  end
end
