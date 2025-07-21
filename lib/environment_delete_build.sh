#!/bin/sh

# Usage: environment_delete_build.sh <environment_input> <build_name> [snapshot_name]
#
# Deletes the release for the given build from the specified logical environment, optionally creating a snapshot before deletion.

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <environment_input> <build_name> [snapshot_name]" >&2
  exit 1
fi

ENV_INPUT="$1"
BUILD_NAME="$2"
SNAPSHOT_NAME="$3"

# Use environment_explode_environment.sh to extract ENV_PREFIX and ENV_NAME
SCRIPT_DIR="$(dirname "$0")"
eval $(sh "$SCRIPT_DIR/environment_explode_environment.sh" "$ENV_INPUT")

ENV_DIR="$SCRIPT_DIR/../environments/$ENV_NAME"
SNAPSHOT_DIR="$ENV_DIR/snapshots"



# Prepare snapshot name if not provided (always UTC, via helper)
if [ -z "$SNAPSHOT_NAME" ]; then
  SNAPSHOT_NAME=$(sh "$SCRIPT_DIR/environment_create_snapshot_name.sh" "$ENV_INPUT")
  # Collect snapshot data (pre-deletion state), but do not write yet
  SNAPSHOT_DATA=$(sh "$SCRIPT_DIR/environment_snapshot.sh" "$ENV_INPUT")
fi

# Find and delete all release files for this build in the logical environment
pattern="$ENV_PREFIX#$BUILD_NAME-release-*.yaml"
found=0
for f in "$ENV_DIR"/$pattern; do
  [ -f "$f" ] || continue
  rm -f "$f"
  found=1
done


if [ $found -eq 0 ]; then
  echo "No release files found for build '$BUILD_NAME' in environment '$ENV_INPUT'"
else
  # Only write snapshot if delete was successful and snapshot name was auto-generated
  if [ -z "$3" ]; then
    mkdir -p "$SNAPSHOT_DIR"
    SNAPSHOT_PATH="$SNAPSHOT_DIR/$SNAPSHOT_NAME"
    printf "%b" "$SNAPSHOT_DATA" > "$SNAPSHOT_PATH"
  fi
  echo "Release for build $BUILD_NAME deleted from '$ENV_INPUT'"
fi
