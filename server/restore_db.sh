#!/usr/bin/env sh
set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: ./restore_db.sh <local-backup-path|backup-filename|s3-key>"
  exit 1
fi

docker compose run --rm backup python -m ops.restore_db "$@"
