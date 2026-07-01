#!/bin/sh
set -eu

if [ "${1:-}" = "start" ]; then
  export PHX_PORT="${PHX_PORT:-4001}"
fi

VMEMO_STORAGE_DIR="${VMEMO_STORAGE_DIR:-/data/storage}"
export VMEMO_STORAGE_DIR

mkdir -p "${VMEMO_STORAGE_DIR}/v1"

/app/bin/vmemo eval "Vmemo.Release.migrate()"

if [ "${1:-}" = "start" ]; then
  nginx -t
  nginx
fi

exec /app/bin/vmemo "$@"
