#!/usr/bin/env bash
set -o errexit
set -o pipefail

cd "$(dirname "$0")"

if [[ -n "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is set — running migrations on PostgreSQL..."
else
  echo "WARNING: DATABASE_URL is not set — migrations will use SQLite."
fi

python manage.py migrate --no-input

echo "Starting gunicorn on 0.0.0.0:${PORT:-8080}..."
exec gunicorn job_api.wsgi:application \
  --bind "0.0.0.0:${PORT:-8080}" \
  --workers 2 \
  --timeout 120 \
  --access-logfile - \
  --error-logfile -
