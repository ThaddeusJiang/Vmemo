#!/bin/sh
set -eu

/app/bin/vmemo eval "Vmemo.Release.migrate()"

if [ "${1:-}" = "start" ] && [ "${VMEMO_ENABLE_NGINX:-}" = "true" ]; then
  nginx -t
  nginx
fi

exec /app/bin/vmemo "$@"
