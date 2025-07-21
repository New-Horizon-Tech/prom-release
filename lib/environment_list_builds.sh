#!/bin/sh
# Usage: environment_list_builds.sh <environment_name>
#
# Prints the current build: version snapshot for the given environment.

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <environment_name>" >&2
  exit 1
fi


# Support prefix@envname, folder always matches full name
ENV_INPUT="$1"

# Use environment_explode_environment.sh to extract PREFIX, ENV_NAME, ENV_DIR
eval $(sh "$(dirname "$0")/environment_explode_environment.sh" "$ENV_INPUT")

if [ ! -d "$ENV_DIR" ]; then
  echo "Environment directory $ENV_NAME does not exist." >&2
  exit 1
fi

sh "$(dirname "$0")/environment_snapshot.sh" "$ENV_INPUT"
