defmodule Vmemo.Repo.Migrations.RenameImagePurposeToInnerPurpose do
  use Ecto.Migration

  def up do
    if memo_images_column?("image_purpose") do
      rename table(:memo_images), :image_purpose, to: :_purpose
    end

    if memo_images_column?("_purpose") do
      # Normalize legacy values and make `nil` the canonical "unset" value.
      execute("""
      UPDATE memo_images
      SET _purpose = NULL
      WHERE _purpose IS NULL OR _purpose = '' OR _purpose = 'library'
      """)

      execute("""
      UPDATE memo_images
      SET _purpose = 'search'
      WHERE _purpose = 'similarity_query'
      """)

      alter table(:memo_images) do
        modify :_purpose, :text, null: true, default: nil
      end
    end
  end

  def down do
    if memo_images_column?("_purpose") and not memo_images_column?("image_purpose") do
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
