defmodule Vmemo.Photos.PhotoNote do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "photos_notes"
    repo Vmemo.Repo

    custom_statements do
      statement :rls_photos_notes_isolation do
        up """
        ALTER TABLE photos_notes ENABLE ROW LEVEL SECURITY;
        ALTER TABLE photos_notes FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS photos_notes_rls_isolation ON photos_notes;
        CREATE POLICY photos_notes_rls_isolation ON photos_notes
          USING (
            CASE
              WHEN current_setting('vmemo.rls_bypass', true) = 'on' THEN true
              ELSE
                EXISTS (
                  SELECT 1
                  FROM photos
                  WHERE photos.id = photos_notes.photo_id
                    AND photos.user_id = nullif(current_setting('vmemo.current_actor_id', true), '')::uuid
                )
                AND EXISTS (
                  SELECT 1
                  FROM notes
                  WHERE notes.id = photos_notes.note_id
                    AND notes.user_id = nullif(current_setting('vmemo.current_actor_id', true), '')::uuid
                )
            END
          )
          WITH CHECK (
            CASE
              WHEN current_setting('vmemo.rls_bypass', true) = 'on' THEN true
              ELSE
                EXISTS (
                  SELECT 1
                  FROM photos
                  WHERE photos.id = photos_notes.photo_id
                    AND photos.user_id = nullif(current_setting('vmemo.current_actor_id', true), '')::uuid
                )
                AND EXISTS (
                  SELECT 1
                  FROM notes
                  WHERE notes.id = photos_notes.note_id
                    AND notes.user_id = nullif(current_setting('vmemo.current_actor_id', true), '')::uuid
                )
            END
          );
        """

        down """
        DROP POLICY IF EXISTS photos_notes_rls_isolation ON photos_notes;
        ALTER TABLE photos_notes NO FORCE ROW LEVEL SECURITY;
        ALTER TABLE photos_notes DISABLE ROW LEVEL SECURITY;
        """
      end
    end
  end

  admin do
    table_columns([:id, :photo_id, :note_id, :inserted_at])
  end

  code_interface do
    define :create
    define :read
    define :destroy
  end

  actions do
    defaults [:read, :create, :destroy]

    create :import do
      accept [:photo_id, :note_id]
    end
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :photo, Vmemo.Photos.Photo do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :note, Vmemo.Photos.Note do
      allow_nil? false
      attribute_writable? true
    end
  end
end
