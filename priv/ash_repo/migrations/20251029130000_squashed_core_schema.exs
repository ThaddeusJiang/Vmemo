defmodule Vmemo.AshRepo.Migrations.SquashedCoreSchema do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION ash_elixir_or(left BOOLEAN, in right ANYCOMPATIBLE, out f1 ANYCOMPATIBLE)
    AS $$ SELECT COALESCE(NULLIF($1, FALSE), $2) $$
    LANGUAGE SQL
    SET search_path = ''
    IMMUTABLE;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_elixir_or(left ANYCOMPATIBLE, in right ANYCOMPATIBLE, out f1 ANYCOMPATIBLE)
    AS $$ SELECT COALESCE($1, $2) $$
    LANGUAGE SQL
    SET search_path = ''
    IMMUTABLE;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_elixir_and(left BOOLEAN, in right ANYCOMPATIBLE, out f1 ANYCOMPATIBLE) AS $$
      SELECT CASE
        WHEN $1 IS TRUE THEN $2
        ELSE $1
      END $$
    LANGUAGE SQL
    SET search_path = ''
    IMMUTABLE;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_elixir_and(left ANYCOMPATIBLE, in right ANYCOMPATIBLE, out f1 ANYCOMPATIBLE) AS $$
      SELECT CASE
        WHEN $1 IS NOT NULL THEN $2
        ELSE $1
      END $$
    LANGUAGE SQL
    SET search_path = ''
    IMMUTABLE;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_trim_whitespace(arr text[])
    RETURNS text[] AS $$
    DECLARE
        start_index INT = 1;
        end_index INT = array_length(arr, 1);
    BEGIN
        WHILE start_index <= end_index AND arr[start_index] = '' LOOP
            start_index := start_index + 1;
        END LOOP;

        WHILE end_index >= start_index AND arr[end_index] = '' LOOP
            end_index := end_index - 1;
        END LOOP;

        IF start_index > end_index THEN
            RETURN ARRAY[]::text[];
        ELSE
            RETURN arr[start_index : end_index];
        END IF;
    END; $$
    LANGUAGE plpgsql
    SET search_path = ''
    IMMUTABLE;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_raise_error(json_data jsonb)
    RETURNS BOOLEAN AS $$
    BEGIN
        RAISE EXCEPTION 'ash_error: %', json_data::text;
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql
    STABLE
    SET search_path = '';
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_raise_error(json_data jsonb, type_signal ANYCOMPATIBLE)
    RETURNS ANYCOMPATIBLE AS $$
    BEGIN
        RAISE EXCEPTION 'ash_error: %', json_data::text;
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql
    STABLE
    SET search_path = '';
    """)

    execute("""
    CREATE OR REPLACE FUNCTION uuid_generate_v7()
    RETURNS UUID
    AS $$
    DECLARE
      timestamp    TIMESTAMPTZ;
      microseconds INT;
    BEGIN
      timestamp    = clock_timestamp();
      microseconds = (cast(extract(microseconds FROM timestamp)::INT - (floor(extract(milliseconds FROM timestamp))::INT * 1000) AS DOUBLE PRECISION) * 4.096)::INT;

      RETURN encode(
        set_byte(
          set_byte(
            overlay(uuid_send(gen_random_uuid()) placing substring(int8send(floor(extract(epoch FROM timestamp) * 1000)::BIGINT) FROM 3) FROM 1 FOR 6
          ),
          6, (b'0111' || (microseconds >> 8)::bit(4))::bit(8)::int
        ),
        7, microseconds::bit(8)::int
      ),
      'hex')::UUID;
    END
    $$
    LANGUAGE PLPGSQL
    SET search_path = ''
    VOLATILE;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION timestamp_from_uuid_v7(_uuid uuid)
    RETURNS TIMESTAMP WITHOUT TIME ZONE
    AS $$
      SELECT to_timestamp(('x0000' || substr(_uuid::TEXT, 1, 8) || substr(_uuid::TEXT, 10, 4))::BIT(64)::BIGINT::NUMERIC / 1000);
    $$
    LANGUAGE SQL
    SET search_path = ''
    IMMUTABLE PARALLEL SAFE STRICT;
    """)

    Oban.Migration.up(version: 11)

    create table(:ash_users, primary_key: false) do
      add :id, :text, null: false, primary_key: true
      add :email, :text, null: false
      add :password, :text
      add :hashed_password, :text, null: false
      add :confirmed_at, :utc_datetime
      add :display_name, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:ash_users, [:email], name: "ash_users_unique_email_index")

    create table(:ash_user_tokens, primary_key: false) do
      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :extra_data, :map
      add :purpose, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :subject, :text, null: false
      add :jti, :text, null: false, primary_key: true
      add :aud, :text, null: false
      add :exp, :utc_datetime, null: false
      add :iss, :text, null: false
      add :sub, :text, null: false
      add :typ, :text, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :ash_user_id,
          references(:ash_users,
            column: :id,
            name: "ash_user_tokens_ash_user_id_fkey",
            type: :text,
            prefix: "public"
          )
    end

    create table(:api_tokens, primary_key: false) do
      add :id, :bigserial, null: false, primary_key: true
      add :token_hash, :text, null: false
      add :name, :text, null: false
      add :description, :text
      add :expires_at, :utc_datetime
      add :last_used_at, :utc_datetime
      add :is_active, :boolean, default: true
      add :created_at, :utc_datetime, null: false
      add :user_id, :bigint

      add :ash_user_id,
          references(:ash_users,
            column: :id,
            name: "api_tokens_ash_user_id_fkey",
            type: :text,
            prefix: "public"
          ),
          null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create table(:photos, primary_key: false) do
      add :id, :text, primary_key: true, null: false
      add :url, :text, null: false
      add :note, :text
      add :file_id, :text
      add :image, :text
      add :user_id, :text

      timestamps(type: :utc_datetime_usec)
    end

    create table(:notes, primary_key: false) do
      add :id, :text, primary_key: true, null: false
      add :text, :text, null: false
      add :user_id, :text

      timestamps(type: :utc_datetime_usec)
    end

    create table(:photos_notes, primary_key: false) do
      add :id, :text, primary_key: true, null: false
      add :photo_id, references(:photos, type: :text, on_delete: :delete_all), null: false
      add :note_id, references(:notes, type: :text, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:photos_notes, [:photo_id])
    create index(:photos_notes, [:note_id])
    create unique_index(:photos_notes, [:photo_id, :note_id])
  end

  def down do
    drop table(:photos_notes)
    drop table(:notes)
    drop table(:photos)
    drop constraint(:api_tokens, "api_tokens_ash_user_id_fkey")
    drop table(:api_tokens)
    drop constraint(:ash_user_tokens, "ash_user_tokens_ash_user_id_fkey")
    drop table(:ash_user_tokens)
    drop_if_exists unique_index(:ash_users, [:email], name: "ash_users_unique_email_index")
    drop table(:ash_users)

    Oban.Migration.down(version: 11)

    execute(
      "DROP FUNCTION IF EXISTS uuid_generate_v7(), timestamp_from_uuid_v7(uuid), ash_raise_error(jsonb), ash_raise_error(jsonb, ANYCOMPATIBLE), ash_elixir_and(BOOLEAN, ANYCOMPATIBLE), ash_elixir_and(ANYCOMPATIBLE, ANYCOMPATIBLE), ash_elixir_or(ANYCOMPATIBLE, ANYCOMPATIBLE), ash_elixir_or(BOOLEAN, ANYCOMPATIBLE), ash_trim_whitespace(text[])"
    )
  end
end
