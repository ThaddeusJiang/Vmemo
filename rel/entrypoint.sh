#!/bin/sh
set -eu

if [ "${1:-}" = "start" ] && command -v nginx >/dev/null 2>&1 && [ -f /etc/nginx/nginx.conf ]; then
  export PHX_PORT="${PHX_PORT:-4001}"
  export VMEMO_STORAGE_ACCEL_REDIRECT="${VMEMO_STORAGE_ACCEL_REDIRECT:-true}"
  START_NGINX=true
else
  START_NGINX=false
fi

/app/bin/vmemo eval "Vmemo.Release.migrate()"

if [ "$START_NGINX" = "true" ]; then
  nginx -t
  nginx
fi

exec /app/bin/vmemo "$@"
