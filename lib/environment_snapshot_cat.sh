#!/bin/sh
# Usage: environment_snapshot_cat.sh <environment_input> <snapshot_filename_without_prefix>
# Prints the contents of the snapshot file for the logical environment.

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <environment_input> <snapshot_filename_without_prefix>" >&2
  exit 1
fi

ENV_INPUT="$1"
SNAPSHOT_BASENAME="$2"
SCRIPT_DIR="$(dirname "$0")"
eval $(sh "$SCRIPT_DIR/environment_explode_environment.sh" "$ENV_INPUT")

SNAPSHOT_FILE="$SCRIPT_DIR/../environments/$ENV_NAME/snapshots/$ENV_PREFIX#$SNAPSHOT_BASENAME"

if [ ! -f "$SNAPSHOT_FILE" ]; then
  echo "Snapshot file does not exist: $SNAPSHOT_FILE" >&2
  exit 1
fi

cat "$SNAPSHOT_FILE"
