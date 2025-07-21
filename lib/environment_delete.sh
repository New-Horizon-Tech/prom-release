#!/bin/sh
# Usage: environment_delete.sh <environment_input>
#
# Deletes a logical or full environment. If the default logical environment or just the environment name is specified, deletes everything. Otherwise, deletes only files for that logical environment. Always deletes the ignore file. Asks for confirmation before deleting.

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <environment_input>" >&2
  exit 1
fi

ENV_INPUT="$1"
SCRIPT_DIR="$(dirname "$0")"
eval $(sh "$SCRIPT_DIR/environment_explode_environment.sh" "$ENV_INPUT")

ENVIRONMENTS_DIR="$SCRIPT_DIR/../environments"
ENV_DIR="$ENVIRONMENTS_DIR/$ENV_NAME"
SNAPSHOTS_DIR="$ENVIRONMENTS_DIR/$ENV_NAME/snapshots"
IGNORE_FILE="$ENVIRONMENTS_DIR/${ENV_PREFIX}#$ENV_NAME.ignore"

if [ ! -d "$ENV_DIR" ]; then
  echo "Environment directory does not exist: $ENV_DIR" >&2
  exit 1
fi

if [ -z "$ENV_PREFIX" ] || [ "$ENV_PREFIX" = "default" ]; then
  echo "Are you sure you want to delete the entire environment '$ENV_NAME'? This will remove all logical environments and all files. [y/N]"
  read confirm
  case "$confirm" in
    y|Y)
      rm -rf "$ENV_DIR"
      rm -f "$ENVIRONMENTS_DIR"/*#$ENV_NAME.ignore
      echo "Deleted environment: $ENV_NAME and all logical environments."
      ;;
    *)
      echo "Aborted. No files deleted."
      exit 0
      ;;
  esac
else
  echo "Are you sure you want to delete logical environment '$ENV_PREFIX@$ENV_NAME'? This will remove only files for this logical environment, including its snapshots. [y/N]"
  read confirm
  case "$confirm" in
    y|Y)
      # Delete release files for this logical environment
      find "$ENV_DIR" -type f -name "$ENV_PREFIX#*-release-*.yaml" -exec rm -f {} +
      # Delete snapshot files for this logical environment
      find "$SNAPSHOTS_DIR" -type f -name "$ENV_PREFIX#*.snapshot" -exec rm -f {} +
      rm -f "$IGNORE_FILE"
      echo "Deleted logical environment: $ENV_PREFIX@$ENV_NAME, its ignore file, and its snapshots."
      ;;
    *)
      echo "Aborted. No files deleted."
      exit 0
      ;;
  esac
fi
