#!/bin/sh
# Usage: environment_ignore_add.sh <environment_input> <command> [build_name]
#
# Commands:
#   add <build_name>    - Add build to ignore file
#   remove <build_name> - Remove build from ignore file
#   list                - List ignored builds


if [ "$#" -lt 2 ]; then
  cat <<EOF
Usage: $0 <environment_input> <add|remove|list> [build_name]

Manages the ignore list for logical environments. The ignore list prevents specific builds from being promoted to an environment.

Arguments:
  <environment_input>   Logical environment name (e.g. test@dev)
  <command>             One of: add, remove, list
  [build_name]          Build name to add/remove (required for add/remove)

Commands:
  add <build_name>      Add a build to the ignore list for the environment
  remove <build_name>   Remove a build from the ignore list for the environment
  list                  List all builds currently ignored for the environment

Examples:
  ./prom.sh env ignore test@dev add my-frontend
  ./prom.sh env ignore test@dev remove my-frontend
  ./prom.sh env ignore test@dev list

The ignore file is stored as: environments/<env_prefix>#<env_name>.ignore
Each build name is listed on a separate line.
EOF
  exit 1
fi


ENV_INPUT="$1"
COMMAND="$2"
BUILD_NAME="$3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

eval $(sh "$SCRIPT_DIR/environment_explode_environment.sh" "$ENV_INPUT")

IGNORE_FILE="$SCRIPT_DIR/../environments/${ENV_PREFIX}#${ENV_NAME}.ignore"

# Create environments directory if missing
ENVIRONMENTS_DIR="$SCRIPT_DIR/../environments"
if [ ! -d "$ENVIRONMENTS_DIR" ]; then
  mkdir -p "$ENVIRONMENTS_DIR"
fi

case "$COMMAND" in
  add)
    if [ -z "$BUILD_NAME" ]; then
      echo "Error: build_name required for add command" >&2
      exit 1
    fi
    echo "$BUILD_NAME" >> "$IGNORE_FILE"
    echo "Added $BUILD_NAME to ignore file"
    # If the build has been promoted to the environment, delete its release
    sh "$SCRIPT_DIR/environment_delete_build.sh" "$ENV_INPUT" "$BUILD_NAME"
    ;;
  remove)
    if [ -z "$BUILD_NAME" ]; then
      echo "Error: build_name required for remove command" >&2
      exit 1
    fi
    if [ ! -f "$IGNORE_FILE" ]; then
      exit 0
    fi
    grep -v "^$BUILD_NAME$" "$IGNORE_FILE" > "$IGNORE_FILE.tmp"
    mv "$IGNORE_FILE.tmp" "$IGNORE_FILE"
    if [ ! -s "$IGNORE_FILE" ]; then
      rm -f "$IGNORE_FILE"
      echo "Removed $BUILD_NAME from ignore file"
    else
      echo "Removed $BUILD_NAME from ignore file"
    fi
    ;;
  list)
    if [ -f "$IGNORE_FILE" ]; then
      cat "$IGNORE_FILE"
    else
      echo "No ignore file found for environment"
    fi
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    exit 1
    ;;
esac
