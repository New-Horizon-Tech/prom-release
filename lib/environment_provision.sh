# Usage: environment_provision.sh <environment_name>

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <environment_name>"
  exit 1
fi

# Support prefix@envname, folder always matches full name

ENV_INPUT="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Use environment_explode_environment.sh to extract PREFIX, ENV_NAME, ENV_DIR
eval $(sh "$SCRIPT_DIR/environment_explode_environment.sh" "$ENV_INPUT")

BUILDS_DIR="$SCRIPT_DIR/../builds"

# Create the environment directory if it doesn't exist
NEW_ENV_CREATED=0
if [ ! -d "$ENV_DIR" ]; then
  mkdir -p "$ENV_DIR"
  echo "Created environment directory: $ENV_PREFIX@$ENV_DIR"
  # Place a readme.txt in the new environment directory
  # Create an empty readme.txt in the new environment directory
  : > "$ENV_DIR/readme.txt"
  # If provisioning a logical environment, provision default@$ENVIRONMENT first
  if [ -n "$ENV_PREFIX" ] && [ "$ENV_PREFIX" != "default" ]; then
    DEFAULT_ENV_INPUT="default@$ENV_NAME"
    "$0" "$DEFAULT_ENV_INPUT"
    if [ $? -ne 0 ]; then
      echo "Failed to provision default environment: $DEFAULT_ENV_INPUT"
      exit 1
    fi
  fi 
  NEW_ENV_CREATED=1
else
  # Check if environment actually has releases
  SNAPSHOT_OUTPUT=$(sh "$(dirname "$0")/environment_snapshot.sh" "$ENV_INPUT")
  if [ -n "$SNAPSHOT_OUTPUT" ]; then
    echo "Environment already exists: $ENV_PREFIX@$ENV_DIR"
    exit 1
  fi
fi

# Prepare snapshot name before promotion
SNAPSHOT_DIR="$ENV_DIR/snapshots"
mkdir -p "$SNAPSHOT_DIR"
SNAPSHOT_NAME=$(sh "$(dirname "$0")/environment_create_snapshot_name.sh" "$ENV_INPUT")
SNAPSHOT_PATH="$SNAPSHOT_DIR/$SNAPSHOT_NAME"
# Collect snapshot data before any changes
SNAPSHOT_DATA=$(sh "$(dirname "$0")/environment_snapshot.sh" "$ENV_INPUT")

# Promote the latest version of all available builds
if [ ! -d "$BUILDS_DIR" ]; then
  echo "No builds directory found. Nothing to promote"
  exit 0
fi

for BUILD_PATH in "$BUILDS_DIR"/*; do
  [ -d "$BUILD_PATH" ] || continue
  BUILD_NAME=$(basename "$BUILD_PATH")
  sh "$(dirname "$0")/build_promote_release.sh" "$BUILD_NAME" "latest" "$ENV_INPUT" "$SNAPSHOT_NAME"
  if [ $? -ne 0 ]; then
      if [ "$NEW_ENV_CREATED" -eq 1 ]; then
      echo "Promotion failed. Cleaning up environment directory: $ENV_DIR"
      rm -rf "$ENV_DIR"
      fi
      exit 1
  fi
done

# Write the snapshot data after successful provision
printf "%b" "$SNAPSHOT_DATA" > "$SNAPSHOT_PATH"

echo "Provisioned environment $ENV_PREFIX@$ENV_DIR with latest releases"
