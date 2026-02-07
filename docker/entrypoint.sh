#!/usr/bin/env sh

required_vars="DATABASE_URL SECRET_KEY_BASE ADMIN_TOKEN SENTRY_DSN RESEND_API_KEY TYPESENSE_URL TYPESENSE_API_KEY MOONDREAM_URL"
optional_vars="OPENROUTER_API_KEY"
missing_required=""
missing_optional=""

for v in $required_vars; do
  if [ -z "$(printenv "$v" 2>/dev/null)" ]; then
    missing_required="$missing_required $v"
  fi
done

for v in $optional_vars; do
  if [ -z "$(printenv "$v" 2>/dev/null)" ]; then
    missing_optional="$missing_optional $v"
  fi
done

if [ -z "${PHX_SERVER:-}" ]; then
  echo "PHX_SERVER not set, defaulting to true"
  export PHX_SERVER=true
fi

echo "Starting Vmemo"
echo "PORT=${PORT:-4000} PHX_HOST=${PHX_HOST:-vmemo.app}"

if [ -n "$missing_optional" ]; then
  echo "Missing optional env vars:$missing_optional"
fi

if [ -n "$missing_required" ]; then
  echo "Missing required env vars:$missing_required"
  exit 1
fi

echo "Running migrations..."
mix ecto.migrate || exit 1

exec mix phx.server
