#!/bin/sh
# Usage: environment_snapshot_restore.sh <environment_input> <snapshot_file>
# Restores the environment to the state described in the snapshot file (no prefix in filename).
# Promotes, adds, or deletes builds as needed.


if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <environment_input> <snapshot_file_name_without_prefix>" >&2
  exit 1
fi

ENV_INPUT="$1"
SNAPSHOT_BASENAME="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
eval $(sh "$SCRIPT_DIR/environment_explode_environment.sh" "$ENV_INPUT")

SNAPSHOT_FILE="$ENV_DIR/snapshots/$ENV_PREFIX#$SNAPSHOT_BASENAME"

if [ ! -d "$ENV_DIR" ]; then
  echo "Environment directory does not exist: $ENV_DIR" >&2
  exit 1
fi

if [ ! -f "$SNAPSHOT_FILE" ]; then
  echo "Snapshot file does not exist: $SNAPSHOT_FILE" >&2
  exit 1
fi



# Prepare snapshot name and collect snapshot data before restoring
SNAPSHOT_NAME=$(sh "$SCRIPT_DIR/environment_create_snapshot_name.sh" "$ENV_INPUT")
SNAPSHOT_DIR="$ENV_DIR/snapshots"
mkdir -p "$SNAPSHOT_DIR"
SNAPSHOT_PATH="$SNAPSHOT_DIR/$SNAPSHOT_NAME"
SNAPSHOT_DATA=$(sh "$SCRIPT_DIR/environment_snapshot.sh" "$ENV_INPUT")

# Read desired state from snapshot file (build: version)
awk -F': ' '{print $1" "$2}' "$SNAPSHOT_FILE" > /tmp/restore_desired_$$

# Get current state from environment
sh "$SCRIPT_DIR/environment_snapshot.sh" "$ENV_INPUT" | awk -F': ' '{print $1" "$2}' > /tmp/restore_current_$$


# Track success of all operations
RESTORE_SUCCESS=1

# Promote or add builds in snapshot that differ or are missing
while read build snap_version; do
  curr_version=$(grep "^$build " /tmp/restore_current_$$ | awk '{print $2}')
  if [ -z "$curr_version" ] || [ "$curr_version" != "$snap_version" ]; then
    sh "$SCRIPT_DIR/build_promote_release.sh" "$build" "$snap_version" "$ENV_INPUT" "$SNAPSHOT_NAME"
    if [ $? -ne 0 ]; then
      RESTORE_SUCCESS=0
    fi
  fi
done < /tmp/restore_desired_$$

# Delete builds present in current but not in snapshot
while read build curr_version; do
  snap_version=$(grep "^$build " /tmp/restore_desired_$$ | awk '{print $2}')
  if [ -z "$snap_version" ]; then
    sh "$SCRIPT_DIR/environment_delete_build.sh" "$ENV_INPUT" "$build" "$SNAPSHOT_NAME"
    if [ $? -ne 0 ]; then
      RESTORE_SUCCESS=0
    fi
  fi
done < /tmp/restore_current_$$

# Write the snapshot only if restore was successful
printf "%b" "$SNAPSHOT_DATA" > "$SNAPSHOT_PATH"
if [ "$RESTORE_SUCCESS" -eq 1 ]; then
  printf "%b" "$SNAPSHOT_DATA" > "$SNAPSHOT_PATH"
  echo "Restored environment $ENV_INPUT to $SNAPSHOT_BASENAME"
else
  echo "Restore encountered errors; no snapshot written."
  # Remove logical environment prefix from the snapshot file name
  SNAPSHOT_FILE_BASENAME=$(basename "$SNAPSHOT_PATH")
  SNAPSHOT_FILE_NOPREFIX=$(echo "$SNAPSHOT_FILE_BASENAME" | sed "s/^$ENV_PREFIX#//")
  echo "To restore the environment back to what it was you can use this snapshot: $SNAPSHOT_FILE_NOPREFIX"
fi

# Clean up temp files
rm -f /tmp/restore_desired_$$ /tmp/restore_current_$$
