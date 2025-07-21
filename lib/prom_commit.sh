#!/bin/sh
# Usage: prom_commit.sh [commit_message]
# Adds all changed files to git, commits with the provided message or a default, and pushes to the remote branch.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMIT_MSG="$1"
EMAIL="$2"
NAME="$3"

if [ -z "$COMMIT_MSG" ]; then
  COMMIT_MSG="Automated commit from prom_commit.sh"
fi

# Set defaults if not provided
if [ -z "$EMAIL" ]; then
  EMAIL="prom-release@local"
fi
if [ -z "$NAME" ]; then
  NAME="Prom Release Bot"
fi

# Set git config for this commit only
git -C "$SCRIPT_DIR/.." config user.email "$EMAIL"
git -C "$SCRIPT_DIR/.." config user.name "$NAME"

# Add all changed files
git -C "$SCRIPT_DIR/.." add -A

# Commit
git -C "$SCRIPT_DIR/.." commit -m "$COMMIT_MSG"

# Get current branch name
BRANCH=$(git -C "$SCRIPT_DIR/.." rev-parse --abbrev-ref HEAD)

# Check if remote tracking branch exists
REMOTE_EXISTS=$(git -C "$SCRIPT_DIR/.." ls-remote --heads origin "$BRANCH")
if [ -z "$REMOTE_EXISTS" ]; then
  # Set up remote tracking branch
  git -C "$SCRIPT_DIR/.." push --set-upstream origin "$BRANCH"
else
  git -C "$SCRIPT_DIR/.." push
fi
