#!/bin/sh
# Usage: build_list_releases.sh <build_name>
#
# Lists all releases (version directories) for the given build name.

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <build_name>" >&2
  exit 1
fi


BUILD_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../builds/$BUILD_NAME"

if [ ! -d "$BUILD_DIR" ]; then
  echo "Build directory $BUILD_DIR does not exist." >&2
  exit 1
fi

ls -1 "$BUILD_DIR" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -Vr
