#!/bin/sh
# Usage: prom_commit.sh [commit_message]
# Adds all changed files to git, commits with the provided message or a default, and pushes to the remote branch.

COMMIT_MSG="$1"
if [ -z "$COMMIT_MSG" ]; then
  COMMIT_MSG="Automated commit from prom_commit.sh"
fi

# Add all changed files
git add -A

# Commit
git commit -m "$COMMIT_MSG"

# Get current branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Check if remote tracking branch exists
REMOTE_EXISTS=$(git ls-remote --heads origin "$BRANCH")
if [ -z "$REMOTE_EXISTS" ]; then
  # Set up remote tracking branch
  git push --set-upstream origin "$BRANCH"
else
  git push
fi
