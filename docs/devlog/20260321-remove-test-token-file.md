# Remove Test Token File

Date: 2026-03-21

## Goal

Stop writing the fixed test API token to a redundant file.

## Changes

- Removed `save_token_to_file/1` from `priv/repo/seeds/test_users.exs`.
- Deleted `priv/repo/test_token.txt`.
- Kept the fixed test token value in the seed output and documentation instead of persisting it to disk.
