# 20260127 align tool versions

## Summary
- Aligned Elixir/OTP versions across CI, project config, and mise.

## Details
- Bumped `mix.exs` Elixir requirement to `~> 1.19`.
- Updated GitHub Actions matrix to OTP 28 and Elixir 1.19.2.
- Added `.tool-versions` for mise to lock Elixir and Erlang versions.
- Refreshed the knowledge doc snippet to match the new Elixir constraint.

## Notes
- Docker image already uses Elixir 1.19.2 with OTP 28.
