#!/bin/sh

set -e

WORKDIR=/opt/pleroma
DATADIR=/var/lib/pleroma

echo "-- Waiting for database..."
while ! pg_isready -U ${DB_USER:-pleroma} -d postgres://${DB_HOST:-db}:5432/${DB_NAME:-pleroma} -t 1; do
    sleep 1s
done

echo "-- Running migrations..."
$WORKDIR/bin/pleroma_ctl migrate

echo "-- Starting!"
exec $WORKDIR/bin/pleroma start
