-- Idempotent e2e auth seed data.
-- This script is intended for isolated e2e databases only.

BEGIN;

WITH target_user AS (
  INSERT INTO ash_users (
    id,
    email,
    hashed_password,
    confirmed_at,
    inserted_at,
    updated_at
  )
  VALUES (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'test@example.com',
    '$2b$12$XN3vVUgFnmApO0oMqEdmp.VuFf97BABUgezpy5VmAmGyfzWp0EMXu',
    timezone('utc', now()),
    timezone('utc', now()),
    timezone('utc', now())
  )
  ON CONFLICT (email)
  DO UPDATE SET
    confirmed_at = EXCLUDED.confirmed_at,
    updated_at = timezone('utc', now())
  RETURNING id
),
selected_user AS (
  SELECT id FROM target_user
  UNION ALL
  SELECT id FROM ash_users WHERE email = 'test@example.com'
  LIMIT 1
)
INSERT INTO api_tokens (
  id,
  name,
  description,
  expires_at,
  token_hash,
  ash_user_id,
  created_at,
  inserted_at,
  updated_at,
  is_active
)
SELECT
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
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
  is_active = true;

WITH selected_user AS (
  SELECT id FROM ash_users WHERE email = 'test@example.com' LIMIT 1
)
INSERT INTO photos (
  id,
  url,
  note,
  file_id,
  ash_user_id,
  inserted_at,
  updated_at
)
SELECT
  '11111111-1111-4111-8111-111111111111',
  '/images/logo.svg',
  'Seeded e2e note reference photo',
  'seeded-e2e-note-reference-logo',
  id,
  timezone('utc', now()),
  timezone('utc', now())
FROM selected_user
ON CONFLICT (id)
DO UPDATE SET
  updated_at = timezone('utc', now());

WITH selected_user AS (
  SELECT id FROM ash_users WHERE email = 'test@example.com' LIMIT 1
)
INSERT INTO notes (
  id,
  text,
  ash_user_id,
  inserted_at,
  updated_at
)
SELECT
  '22222222-2222-4222-8222-222222222222',
  'Seeded e2e note reference',
  id,
  timezone('utc', now()),
  timezone('utc', now())
FROM selected_user
ON CONFLICT (id)
DO UPDATE SET
  updated_at = timezone('utc', now());

INSERT INTO photos_notes (
  id,
  photo_id,
  note_id,
  inserted_at
)
VALUES (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  timezone('utc', now())
)
ON CONFLICT (id)
DO NOTHING;

COMMIT;
