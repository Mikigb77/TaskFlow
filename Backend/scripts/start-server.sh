#!/bin/sh
set -eu
if [ "${RUN_LOCAL_BOOTSTRAP:-0}" = "1" ]; then
  python manage.py migrate --noinput
  python manage.py seed_test_user
fi
exec gunicorn config.wsgi:application --bind "0.0.0.0:${PORT:-8000}" \
  --workers 1 --threads 4 --timeout 120 --access-logfile - \
  --access-logformat '%(s)s %(m)s %(U)s'
