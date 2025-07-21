#!/bin/sh
# Usage: environment_explode_environment.sh <environment_input>
#
# Given an environment input (e.g. test@dev or dev), prints:
#   ENV_NAME=<env_name>
#   PREFIX=<prefix> (empty if default or no prefix)
#   ENV_DIR=environments/<env_name>

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <environment_input>" >&2
  exit 1
fi

ENV_INPUT="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$ENV_INPUT" in
  *@*)
    ENV_PREFIX=$(echo "$ENV_INPUT" | cut -d'@' -f1)
    ENV_NAME=$(echo "$ENV_INPUT" | cut -d'@' -f2)
    ;;
  *)
    ENV_PREFIX="default"
    ENV_NAME="$ENV_INPUT"
    ;;
esac

ENV_DIR="$SCRIPT_DIR/../environments/$ENV_NAME"

# Output as shell variable assignments
cat <<EOF
ENV_NAME="$ENV_NAME"
ENV_PREFIX="$ENV_PREFIX"
ENV_DIR="$ENV_DIR"
EOF
