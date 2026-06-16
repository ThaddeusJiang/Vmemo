#!/bin/sh
set -eu

if [ "${1:-}" = "start" ]; then
  export PHX_PORT="${PHX_PORT:-4001}"
fi

/app/bin/vmemo eval "Vmemo.Release.migrate()"

if [ "${1:-}" = "start" ]; then
  nginx -t
  nginx
fi

exec /app/bin/vmemo "$@"
