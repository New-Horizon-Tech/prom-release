#!/bin/sh
# Usage: environment_create_snapshot_name.sh <environment_input>
#
# Prints a UTC timestamped snapshot name prefixed with the logical environment prefix (if any):
#   <prefix>YYYY.MM.DD.HH.MM.SS.snapshot

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <environment_input>" >&2
  exit 1
fi

ENV_INPUT="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
eval $(sh "$SCRIPT_DIR/environment_explode_environment.sh" "$ENV_INPUT")

SNAPSHOT_NAME=$(date -u +%Y.%m.%d.%H.%M.%S.snapshot)
if [ -n "$ENV_PREFIX" ]; then
  echo "$ENV_PREFIX#$SNAPSHOT_NAME"
else
  echo "$SNAPSHOT_NAME"
fi
