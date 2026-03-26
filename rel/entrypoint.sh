#!/bin/sh
set -eu

/app/bin/vmemo eval "Vmemo.Release.migrate()"
/app/bin/vmemo eval "Vmemo.Release.ts_migrate()"

exec /app/bin/vmemo "$@"
