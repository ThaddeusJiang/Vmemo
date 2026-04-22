#!/bin/sh
set -eu

/app/bin/vmemo eval "Vmemo.Release.migrate()"

if [ "${E2E_AUTO_SEED:-false}" = "true" ]; then
  /app/bin/vmemo eval "Vmemo.Release.seed_e2e()"
fi

exec /app/bin/vmemo "$@"
