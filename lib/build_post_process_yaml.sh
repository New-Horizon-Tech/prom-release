#!/bin/sh
# Usage: build_post_process_yaml.sh <yaml_file> <environment_prefix>
#
# For each line in the yaml file, if it contains a placeholder like
#   [LogicalEnvironmentInsertBefore=some-text]
# then insert the environment prefix before every occurrence of 'some-text' on that line.
# Writes the updated file back to disk.

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <yaml_file> <environment_prefix>" >&2
  exit 1
fi

YAML_FILE="$1"
ENV_PREFIX="$2"

TMP_FILE=$(mktemp)

while IFS= read -r line || [ -n "$line" ]; do
  newline="$line"
  # Check for LogicalEnvironmentInsertBefore
  if echo "$line" | grep -q '\[LogicalEnvironmentInsertBefore='; then
    targetBefore=$(echo "$line" | sed -n 's/.*\[LogicalEnvironmentInsertBefore=\([^]]*\)\].*/\1/p')
    if [ -n "$targetBefore" ]; then
      newline=$(echo "$newline" | sed "s/$targetBefore/$ENV_PREFIX-$targetBefore/g")
    fi
    # Remove the placeholder
    newline=$(echo "$newline" | sed 's/ *\[LogicalEnvironmentInsertBefore=[^]]*\] *//g')
  fi
  # Check for LogicalEnvironmentInsertAfter
  if echo "$line" | grep -q '\[LogicalEnvironmentInsertAfter='; then
    targetAfter=$(echo "$line" | sed -n 's/.*\[LogicalEnvironmentInsertAfter=\([^]]*\)\].*/\1/p')
    if [ -n "$targetAfter" ]; then
      newline=$(echo "$newline" | sed "s/$targetAfter/$targetAfter-$ENV_PREFIX/g")
    fi
    # Remove the placeholder
    newline=$(echo "$newline" | sed 's/ *\[LogicalEnvironmentInsertAfter=[^]]*\] *//g')
  fi
  # Remove trailing # with only whitespace
  newline=$(echo "$newline" | sed 's/#[[:space:]]*$//')
  # Ensure space after # if comment remains
  newline=$(echo "$newline" | sed 's/#\([^ ]\)/# \1/g')
  echo "$newline" >> "$TMP_FILE"
done < "$YAML_FILE"

mv "$TMP_FILE" "$YAML_FILE"
