alias Ecto.Adapters.SQL
alias Vmemo.Repo

user_email = "test@example.com"
user_id = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
api_token_id = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
seeded_image_id = "11111111-1111-4111-8111-111111111111"
seeded_note_id = "22222222-2222-4222-8222-222222222222"
seeded_image_note_join_id = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
user_password_hash = Bcrypt.hash_pwd_salt("pass123456")

user_id_bin = Ecto.UUID.dump!(user_id)
api_token_id_bin = Ecto.UUID.dump!(api_token_id)
seeded_image_id_bin = Ecto.UUID.dump!(seeded_image_id)
seeded_note_id_bin = Ecto.UUID.dump!(seeded_note_id)
seeded_image_note_join_id_bin = Ecto.UUID.dump!(seeded_image_note_join_id)

Repo.transaction(fn ->
  SQL.query!(
    Repo,
    """
    INSERT INTO auth_users (
      id,
      email,
      hashed_password,
      confirmed_at,
      inserted_at,
      updated_at
    )
    VALUES ($1, $2, $3, timezone('utc', now()), timezone('utc', now()), timezone('utc', now()))
    ON CONFLICT (email)
    DO UPDATE SET
      confirmed_at = EXCLUDED.confirmed_at,
      updated_at = timezone('utc', now())
    """,
    [
      user_id_bin,
      user_email,
      user_password_hash
    ]
  )

  SQL.query!(
    Repo,
    """
    WITH selected_user AS (
      SELECT id FROM auth_users WHERE email = $1 LIMIT 1
    )
    INSERT INTO auth_api_tokens (
      id,
      name,
      description,
      expires_at,
      token_hash,
      user_id,
      created_at,
      inserted_at,
      updated_at,
      is_active
    )
    SELECT
      $2,
      'Test API Token',
      'Fixed token for testing: test123456',
      timezone('utc', now()) + interval '180 days',
      '85777f270ad7cf2a790981bbae3c4e484a1dc55e24a77390d692fbf1cffa12fa',
      id,
      timezone('utc', now()),
      timezone('utc', now()),
      timezone('utc', now()),
      true
    FROM selected_user
    ON CONFLICT (id)
    DO UPDATE SET
      updated_at = timezone('utc', now()),
      is_active = true
    """,
    [user_email, api_token_id_bin]
  )

  SQL.query!(
    Repo,
    """
    WITH selected_user AS (
      SELECT id FROM auth_users WHERE email = $1 LIMIT 1
    )
    INSERT INTO memo_images (
      id,
      url,
      note,
      file_id,
      user_id,
      inserted_at,
      updated_at
    )
    SELECT
      $2,
      '/images/logo.svg',
      'Seeded e2e note reference photo',
      'seeded-e2e-note-reference-logo',
      id,
      timezone('utc', now()),
      timezone('utc', now())
    FROM selected_user
    ON CONFLICT (id)
    DO UPDATE SET
      updated_at = timezone('utc', now())
    """,
    [user_email, seeded_image_id_bin]
  )

  SQL.query!(
    Repo,
    """
    WITH selected_user AS (
      SELECT id FROM auth_users WHERE email = $1 LIMIT 1
    )
    INSERT INTO memo_notes (
      id,
      text,
      user_id,
      inserted_at,
      updated_at
    )
    SELECT
      $2,
      'Seeded e2e note reference',
      id,
      timezone('utc', now()),
      timezone('utc', now())
    FROM selected_user
    ON CONFLICT (id)
    DO UPDATE SET
      updated_at = timezone('utc', now())
    """,
    [user_email, seeded_note_id_bin]
  )

  SQL.query!(
    Repo,
    """
    INSERT INTO memo_images_notes (
      id,
      image_id,
      note_id,
      inserted_at
    )
    VALUES ($1, $2, $3, timezone('utc', now()))
    ON CONFLICT (id)
    DO NOTHING
    """,
    [seeded_image_note_join_id_bin, seeded_image_id_bin, seeded_note_id_bin]
  )
end)
