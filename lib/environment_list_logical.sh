#!/bin/sh
# Usage: environment_list_logical.sh <environment_name>
#
# Lists all logical environments for the given non-prefixed environment (e.g. dev)
# Prints one line per logical environment: default first, then others sorted alphabetically

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <environment_name>" >&2
  exit 1
fi


ENV_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_DIR="$SCRIPT_DIR/../environments/$ENV_NAME"

if [ ! -d "$ENV_DIR" ]; then
  echo "Environment directory $ENV_NAME does not exist." >&2
  exit 1
fi

# Find all release files in the environment directory
release_files=$(ls "$ENV_DIR"/*-release-*.yaml 2>/dev/null)



# Collect logical prefixes
prefixes=""
default_found=0
for f in $release_files; do
  base=$(basename "$f")
  # Match prefix#build-release-*.yaml or build-release-*.yaml
  if echo "$base" | grep -q "^.*#.*-release-"; then
    prefix=$(echo "$base" | sed 's/#.*-release-.*//')
    prefixes="$prefixes\n$prefix"
  else
    default_found=1
  fi
done

# Remove duplicates and sort
logical_prefixes=$(echo "$prefixes" | sort | uniq)


# Print default first
if [ "$default_found" -eq 1 ]; then
  echo "default@$ENV_NAME"
fi

# Print other logical environments alphabetically
for prefix in $logical_prefixes; do
  if [ -n "$prefix" ]; then
    echo "$prefix@$ENV_NAME"
  fi
done
