# 2026-01-26 Fix seed uuid encoding

## Context
- Seeding test users failed with Postgrex UUID encoding error when using raw SQL.

## Changes
- Convert `user.id` to binary UUID using `Ecto.UUID.dump!` before passing to raw SQL.
- Apply the same conversion for user confirmation update and API token insert.

## Notes
- No behavior changes beyond correct UUID encoding for raw SQL.
