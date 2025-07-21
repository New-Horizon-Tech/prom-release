#!/bin/sh
# Usage: environment_snapshot_list.sh <environment_input>
# Lists snapshot files for a logical environment (prefix@envname).

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <environment_input>" >&2
  exit 1
fi

ENV_INPUT="$1"
SCRIPT_DIR="$(dirname "$0")"
eval $(sh "$SCRIPT_DIR/environment_explode_environment.sh" "$ENV_INPUT")

SNAPSHOTS_DIR="$SCRIPT_DIR/../environments/$ENV_NAME/snapshots"
if [ ! -d "$SNAPSHOTS_DIR" ]; then
  echo "Snapshots directory does not exist: $SNAPSHOTS_DIR" >&2
  exit 1
fi

# List only snapshot files for the logical environment, sorted with latest first
for f in $(find "$SNAPSHOTS_DIR" -type f -name "$ENV_PREFIX#*.snapshot" | sort -r); do
  base=$(basename "$f")
  # Strip prefix from output
  no_prefix=$(echo "$base" | sed "s/^$ENV_PREFIX#//")
  echo "$no_prefix"
done
