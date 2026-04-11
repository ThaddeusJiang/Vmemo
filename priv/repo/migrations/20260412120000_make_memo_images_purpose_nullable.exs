defmodule Vmemo.Repo.Migrations.MakeMemoImagesPurposeNullable do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE memo_images
    SET _purpose = NULL
    WHERE _purpose = ''
    """)

    alter table(:memo_images) do
      modify :_purpose, :text, null: true, default: nil
    end
  end

  def down do
    execute("""
    UPDATE memo_images
    SET _purpose = ''
    WHERE _purpose IS NULL
    """)

    alter table(:memo_images) do
      modify :_purpose, :text, null: false, default: ""
    end
  end
end
