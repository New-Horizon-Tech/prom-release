#!/bin/sh
# Usage: environment_snapshot.sh <environment_dir>
#
# Prints to stdout a list of build: version for all builds in the environment directory.

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <environment_dir>" >&2
  exit 1
fi

# Support prefix@envname, folder always matches full name
ENV_INPUT="$1"

# Use environment_explode_environment.sh to extract PREFIX, ENV_NAME, ENV_DIR
eval $(sh "$(dirname "$0")/environment_explode_environment.sh" "$ENV_INPUT")

# Only output one row per build (first file found for each build)
seen=""
for f in "$ENV_DIR"/${ENV_PREFIX}#*-release-*.yaml; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  # Remove prefix if present (prefix#build-release-*.yaml or build-release-*.yaml)
  build_name=$(echo "$base" | sed 's/^.*#//; s/-release-.*//')
  case ",$seen," in
    *,$build_name,*) continue;;
  esac
  version=$(awk '/^metadata:/ {inmeta=1} inmeta && /version:/ {gsub(/"/, "", $2); print $2; exit}' "$f")
  if [ -n "$build_name" ] && [ -n "$version" ]; then
    echo "$build_name: $version"
    seen="$seen,$build_name"
  fi
done
