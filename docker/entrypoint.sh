#!/usr/bin/env sh
set -e

if [ -n "$DATABASE_URL" ]; then
  echo "Using DATABASE_URL=$DATABASE_URL"
fi

exec uvicorn main:app --host 0.0.0.0 --port 8005
