#!/bin/sh
set -eu

if [ "${1:-}" = "start" ]; then
  export PHX_PORT="${PHX_PORT:-4001}"
fi

if [ "${VMEMO_STORAGE_DIR+x}" = "x" ] && [ -z "${VMEMO_STORAGE_DIR}" ]; then
  echo "VMEMO_STORAGE_DIR must be a non-empty storage directory path." >&2
  exit 1
fi

VMEMO_STORAGE_DIR="${VMEMO_STORAGE_DIR:-/data/storage}"
export VMEMO_STORAGE_DIR

mkdir -p "${VMEMO_STORAGE_DIR}/v1"

/app/bin/vmemo eval "Vmemo.Release.migrate()"

if [ "${1:-}" = "start" ] && [ "${VMEMO_ENABLE_NGINX:-}" = "true" ]; then
  escaped_storage_dir="$(printf '%s\n' "${VMEMO_STORAGE_DIR}" | sed 's/[&|]/\\&/g')"
  sed "s|/data/storage|${escaped_storage_dir}|g" \
    /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
  nginx -t
  nginx
fi

exec /app/bin/vmemo "$@"
