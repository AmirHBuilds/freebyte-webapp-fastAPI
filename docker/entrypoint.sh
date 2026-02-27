#!/usr/bin/env sh
set -e

if [ -n "$DATABASE_URL" ]; then
  echo "Using DATABASE_URL=$DATABASE_URL"
fi

# Run database migrations if alembic is configured.
alembic upgrade head || echo "Skipping alembic upgrade (failed or not configured yet)."

exec uvicorn main:app --host 0.0.0.0 --port 8005
