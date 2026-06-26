#!/usr/bin/env bash
set -o errexit

cd "$(dirname "$0")"

echo "Applying database migrations..."
python manage.py migrate --no-input

echo "Starting gunicorn on port ${PORT:-8000}..."
exec gunicorn job_api.wsgi:application --bind "0.0.0.0:${PORT:-8000}"
