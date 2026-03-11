#!/bin/bash
set -e

# Wait for database and run migrations
for i in {1..60}; do
  mix ash_postgres.migrate && break
  [ $i -eq 60 ] && echo "Timeout: Failed to run migrations" && exit 1
  sleep 1
done

# Start the Phoenix server
exec "$@"
