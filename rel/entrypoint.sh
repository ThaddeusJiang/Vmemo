#!/bin/sh
set -eu

/app/bin/vmemo eval "Vmemo.Release.migrate()"

exec /app/bin/vmemo "$@"
