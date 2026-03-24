#!/bin/sh
set -eu

mix ash.migrate
mix ts.migrate

exec "$@"
