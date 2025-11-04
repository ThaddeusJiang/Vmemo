defmodule Vmemo.AshRepo.Migrations.FixPhotosIdColumnToUuid do
  use Ecto.Migration

  def up do
    # Drop foreign key constraints
    execute "ALTER TABLE photos_notes DROP CONSTRAINT IF EXISTS photos_notes_photo_id_fkey"
    execute "ALTER TABLE photos_notes DROP CONSTRAINT IF EXISTS photos_notes_note_id_fkey"

    # Convert columns to UUID type
    # Since tables are empty, we can use USING clause without data conversion issues
    execute "ALTER TABLE photos ALTER COLUMN id TYPE uuid USING id::uuid"
    execute "ALTER TABLE photos ALTER COLUMN user_id TYPE uuid USING user_id::uuid"

    execute "ALTER TABLE notes ALTER COLUMN id TYPE uuid USING id::uuid"
    execute "ALTER TABLE notes ALTER COLUMN user_id TYPE uuid USING user_id::uuid"

    execute "ALTER TABLE photos_notes ALTER COLUMN id TYPE uuid USING id::uuid"
    execute "ALTER TABLE photos_notes ALTER COLUMN photo_id TYPE uuid USING photo_id::uuid"
    execute "ALTER TABLE photos_notes ALTER COLUMN note_id TYPE uuid USING note_id::uuid"

    # Recreate foreign key constraints
    execute """
    ALTER TABLE photos_notes
    ADD CONSTRAINT photos_notes_photo_id_fkey
    FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE
    """

    execute """
    ALTER TABLE photos_notes
    ADD CONSTRAINT photos_notes_note_id_fkey
    FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
    """
  end

  def down do
    # Drop foreign key constraints
    execute "ALTER TABLE photos_notes DROP CONSTRAINT IF EXISTS photos_notes_photo_id_fkey"
    execute "ALTER TABLE photos_notes DROP CONSTRAINT IF EXISTS photos_notes_note_id_fkey"

    # Convert columns back to text type
    execute "ALTER TABLE photos ALTER COLUMN id TYPE text USING id::text"
    execute "ALTER TABLE photos ALTER COLUMN user_id TYPE text USING user_id::text"

    execute "ALTER TABLE notes ALTER COLUMN id TYPE text USING id::text"
    execute "ALTER TABLE notes ALTER COLUMN user_id TYPE text USING user_id::text"

    execute "ALTER TABLE photos_notes ALTER COLUMN id TYPE text USING id::text"
    execute "ALTER TABLE photos_notes ALTER COLUMN photo_id TYPE text USING photo_id::text"
    execute "ALTER TABLE photos_notes ALTER COLUMN note_id TYPE text USING note_id::text"

    # Recreate foreign key constraints with text type
    execute """
    ALTER TABLE photos_notes
    ADD CONSTRAINT photos_notes_photo_id_fkey
    FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE
    """

    execute """
    ALTER TABLE photos_notes
    ADD CONSTRAINT photos_notes_note_id_fkey
    FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
    """
  end
end
