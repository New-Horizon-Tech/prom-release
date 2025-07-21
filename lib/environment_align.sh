#!/bin/sh

# Usage: environment_align.sh <target_environment> <source_environment>
#
# Aligns the target environment to match the versions of all services in the source environment.
# For each service, finds the version currently promoted in the source environment and promotes that version to the target environment.
#
# Arguments:
#   <target_environment>  The environment to align (will be updated)
#   <source_environment>  The environment to copy versions from (reference)
#
# Example:
#   ./environment_align.sh staging dev
#
# This will:
#   - For each service in 'dev', find the version currently promoted
#   - Promote that version to 'staging' using build_promote_release.sh


if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <target_environment> <source_environment>"
  echo
  echo "Aligns the target environment to match the versions of all services in the source environment."
  echo
  echo "Arguments:"
  echo "  <target_environment>  The environment to align (will be updated)"
  echo "  <source_environment>  The environment to copy versions from (reference)"
  echo
  echo "Example:"
  echo "  $0 staging dev"
  echo
  echo "This will:"
  echo "  - For each service in 'dev', find the version currently promoted"
  echo "  - Promote that version to 'staging' using build_promote_release.sh"
  exit 1
fi

# For target environment
# Extract prefix and environment name for target
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TGT_INPUT="$1"
eval $(sh "$(dirname "$0")/environment_explode_environment.sh" "$TGT_INPUT")
TGT_ENV_NAME="$ENV_NAME"
TGT_ENV_PREFIX="$ENV_PREFIX"
TGT_DIR="$ENV_DIR"

# For source environment
# Extract prefix and environment name for source
SRC_INPUT="$2"
eval $(sh "$(dirname "$0")/environment_explode_environment.sh" "$SRC_INPUT")
SRC_ENV_NAME="$ENV_NAME"
SRC_ENV_PREFIX="$ENV_PREFIX"
SRC_DIR="$ENV_DIR"

BUILDS_DIR="builds"

# Check if source environment exists
if [ ! -d "$SRC_DIR" ]; then
  echo "Source environment directory $SRC_DIR does not exist. Aborting"
  exit 1
fi

# Check if target environment exists
if [ ! -d "$TGT_DIR" ]; then
  echo "Target environment directory $TGT_DIR does not exist. Aborting"
  exit 1
fi

# Create a snapshot of the target environment before alignment

SNAPSHOT_DIR="$TGT_DIR/snapshots"
mkdir -p "$SNAPSHOT_DIR"
SNAPSHOT_NAME=$(sh "$(dirname "$0")/environment_create_snapshot_name.sh" "$ENV_INPUT")

SNAPSHOT_PATH="$SNAPSHOT_DIR/$SNAPSHOT_NAME"
sh "$(dirname "$0")/environment_snapshot.sh" "$TGT_INPUT" > "$SNAPSHOT_PATH"

ROLLBACK_NEEDED=0

# Use environment_snapshot.sh to get the list of builds and versions from the source and target environments
SRC_SNAPSHOT=$(mktemp)
TGT_SNAPSHOT=$(mktemp)
sh "$(dirname "$0")/environment_snapshot.sh" "$SRC_INPUT" > "$SRC_SNAPSHOT"
sh "$(dirname "$0")/environment_snapshot.sh" "$TGT_INPUT" > "$TGT_SNAPSHOT"

while IFS= read -r line; do
  build_name=$(echo "$line" | cut -d: -f1 | xargs)
  src_version=$(echo "$line" | cut -d: -f2 | xargs)
  if [ -z "$build_name" ] || [ -z "$src_version" ]; then
    echo "Could not determine build or version for line: $line, skipping"
    continue
  fi
  tgt_version=$(grep "^$build_name:" "$TGT_SNAPSHOT" | cut -d: -f2 | xargs)
  if [ "$src_version" = "$tgt_version" ]; then
    continue
  fi
  sh "$(dirname "$0")/build_promote_release.sh" "$build_name" "$src_version" "$TGT_INPUT" "$SNAPSHOT_NAME"
  if [ $? -ne 0 ]; then
    echo "Failed to promote $build_name version $src_version to $TGT_INPUT"
    ROLLBACK_NEEDED=1
    break
  fi
done < "$SRC_SNAPSHOT"

rm -f "$SRC_SNAPSHOT" "$TGT_SNAPSHOT"

if [ "$ROLLBACK_NEEDED" -eq 1 ]; then
  echo "Alignment failed. Rolling back to previous environment state"
  # Read snapshot and revert each build
  while IFS= read -r line; do
    build_name=$(echo "$line" | cut -d: -f1 | xargs)
    version=$(echo "$line" | cut -d: -f2 | xargs)
    if [ -n "$build_name" ] && [ -n "$version" ]; then
      sh "$(dirname "$0")/build_promote_release.sh" "$build_name" "$version" "$TGT_INPUT"
    fi
  done < "$SNAPSHOT_PATH"
  rm -f "$SNAPSHOT_PATH"
  echo "Rollback complete."
  exit 1
else
  echo "Aligned $TGT_INPUT to match $SRC_INPUT versions for all services"
fi
