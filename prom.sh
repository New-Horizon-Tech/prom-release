#!/bin/sh


# Usage: prom.sh <build|env> <subcommand> [args...]
#
# Build commands:
#   create <build_name> <version_yaml_file> <yaml_directory>
#   list [build_name]
#   list-releases <build_name>
#   promote <build_name> <version> <environment>
#
# Environment commands:
#   list
#   list-builds <environment_name>
#   provision <environment_name>
#   align <target_environment> <source_environment>


set -e

# Determine the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"


if [ $# -eq 0 ]; then
  echo "Usage: $0 <build|env|commit> <subcommand> ..."
  echo
  echo "Current environments:"
  if ls -1 "$SCRIPT_DIR/environments" 1>/dev/null 2>&1; then
    ls -1 "$SCRIPT_DIR/environments" | sed 's/^/  /'
  else
    echo "  (none)"
  fi
  echo
  echo "Current builds:"
  if ls -1 "$SCRIPT_DIR/builds" 1>/dev/null 2>&1; then
    ls -1 "$SCRIPT_DIR/builds" | sed 's/^/  /'
  else
    echo "  (none)"
  fi
  exit 1
fi

case "$1" in
  build)
    case "$2" in 
      create)
        shift 2
        exec "$SCRIPT_DIR/lib/build_create_release.sh" "$@"
        ;; 
      list)
        shift 2
        if [ -n "$1" ]; then
          ls -1 "$SCRIPT_DIR/builds/$1" 2>/dev/null || echo "No such build: $1"
        else
          ls -1 "$SCRIPT_DIR/builds" 2>/dev/null || echo "No builds found"
        fi
        ;;
      list-releases)
        shift 2
        if [ -z "$1" ]; then
          echo "Usage: $0 build list-releases <build_name>"
          exit 1
        fi
        exec "$SCRIPT_DIR/lib/build_list_releases.sh" "$1"
        ;;
      promote)
        shift 2
        exec "$SCRIPT_DIR/lib/build_promote_release.sh" "$@"
        ;;
      *)
        echo "Usage: $0 build <create|list|list-releases|promote> ..."
        exit 1
        ;;
    esac
    ;;
  env)
    case "$2" in
      list)
        shift 2
        find "$SCRIPT_DIR/environments" -maxdepth 1 -type d ! -name environments | sed "s|^$SCRIPT_DIR/environments/||" | grep -v '^$' || echo "No environments found"
        ;;
      list-logical)
        shift 2
        exec "$SCRIPT_DIR/lib/environment_list_logical.sh" "$@"
        ;;
      list-releases)
        shift 2
        if [ -z "$1" ]; then
          echo "Usage: $0 env list-builds <environment_name>"
          exit 1
        fi
        exec "$SCRIPT_DIR/lib/environment_list_builds.sh" "$1"
        ;;
      list-snapshots)
        shift 2
        if [ -z "$1" ]; then
          echo "Usage: $0 env list-snapshots <environment_input>"
          exit 1
        fi
        exec "$SCRIPT_DIR/lib/environment_snapshot_list.sh" "$1"
        ;;
      cat-snapshot)
        shift 2
        if [ -z "$1" ] || [ -z "$2" ]; then
          echo "Usage: $0 env cat-snapshot <environment_input> <snapshot_filename_without_prefix>"
          exit 1
        fi
        exec "$SCRIPT_DIR/lib/environment_snapshot_cat.sh" "$1" "$2"
        ;;
      restore-snapshot)
        shift 2
        if [ -z "$1" ] || [ -z "$2" ]; then
          echo "Usage: $0 env restore-snapshot <environment_input> <snapshot_filename_without_prefix>"
          exit 1
        fi
        exec "$SCRIPT_DIR/lib/environment_snapshot_restore.sh" "$1" "$2"
        ;;
      provision)
        shift 2
        exec "$SCRIPT_DIR/lib/environment_provision.sh" "$@"
        ;;
      align)
        shift 2
        exec "$SCRIPT_DIR/lib/environment_align.sh" "$@"
        ;;
      ignore)
        shift 2
        exec "$SCRIPT_DIR/lib/environment_ignore_add.sh" "$@"
        ;;
      delete-build)
        shift 2
        exec "$SCRIPT_DIR/lib/environment_delete_build.sh" "$@"
        ;;
      rm)
        shift 2
        exec "$SCRIPT_DIR/lib/environment_delete.sh" "$@"
        ;;
      *)
        echo "Usage: $0 env <list|list-logical|provision|list-releases|list-snapshots|cat-snapshot|restore-snapshot|align|ignore|delete-build|rm> ..."
        exit 1
        ;;
    esac
    ;;
  commit)
    shift 1
    exec "$SCRIPT_DIR/lib/prom_commit.sh" "$@"
    ;;
  *)
    echo "Usage: $0 <build|env|commit> <subcommand> ..."
    exit 1
    ;;
esac
