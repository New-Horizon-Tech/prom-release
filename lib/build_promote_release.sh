

# Usage: build_promote_release.sh <build_name> <version|latest> <environment> [snapshot_name]
#
# <build_name>     - Name of the build/service
# <version>        - Version to promote (e.g. 1.0.3) or 'latest' to promote the most recent version
# <environment>    - Target environment name
# [snapshot_name]  - Optional snapshot name (default: current timestamp)


if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 <build_name> <version|latest> <environment> [snapshot_name]"
  echo "  <build_name>     - Name of the build/service"
  echo "  <version>        - Version to promote (e.g. 1.0.3) or 'latest' to promote the most recent version"
  echo "  <environment>    - Target environment name"
  echo "  [snapshot_name]  - Optional snapshot name (default: current timestamp)"
  exit 1
fi

BUILD_NAME="$1"
VERSION="$2"
ENV_INPUT="$3"
SNAPSHOT_NAME="$4"

# Use environment_explode_environment.sh to extract PREFIX, ENV_NAME, ENV_DIR
eval $(sh "$(dirname "$0")/environment_explode_environment.sh" "$ENV_INPUT")

SNAPSHOT_DIR="$ENV_DIR/snapshots"

# If version is 'latest', find the latest version directory
if [ "$VERSION" = "latest" ]; then
  BUILD_PATH="builds/$BUILD_NAME"
  if [ ! -d "$BUILD_PATH" ]; then
    echo "Build directory $BUILD_PATH does not exist. Aborting"
    exit 1
  fi
  LATEST_VERSION=$(ls -1 "$BUILD_PATH" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)
  if [ -z "$LATEST_VERSION" ]; then
    echo "No versions found for build $BUILD_NAME. Aborting"
    exit 1
  fi
  VERSION="$LATEST_VERSION"
fi

# Prepare snapshot name if not provided (always UTC, via helper)
if [ -z "$SNAPSHOT_NAME" ]; then
  SNAPSHOT_NAME=$(sh "$(dirname "$0")/environment_create_snapshot_name.sh" "$ENV_INPUT")
fi

# Collect snapshot data (pre-promotion state), but do not write yet
SNAPSHOT_DATA=$(sh "$(dirname "$0")/environment_snapshot.sh" "$ENV_INPUT")

VERSION_DIR="builds/$BUILD_NAME/$VERSION"

# Check if environment directory exists
if [ ! -d "$ENV_DIR" ]; then
  echo "Environment directory $ENV_DIR does not exist. Aborting"
  exit 1
fi

# Check if version directory exists
if [ ! -d "$VERSION_DIR" ]; then
  echo "Version directory $VERSION_DIR does not exist. Aborting"
  exit 1
fi


# Check ignore file before promoting
IGNORE_FILE="$(dirname "$0")/../environments/${ENV_PREFIX}#${ENV_NAME}.ignore"
if [ -f "$IGNORE_FILE" ]; then
  if grep -Fxq "$BUILD_NAME" "$IGNORE_FILE"; then
    echo "Ignoring build '$BUILD_NAME'"
    exit 0
  fi
fi

# Remove previous release files for this build in the environment directory
find "$ENV_DIR" -type f -name "$ENV_PREFIX#${BUILD_NAME}-release-*.yaml" -exec rm -f {} +

# Copy new release files from the version directory to the environment directory
for f in "$VERSION_DIR"/*.yaml; do
  base=$(basename "$f")
  target_file="$ENV_DIR/$ENV_PREFIX#${BUILD_NAME}-release-$base"
  cp "$f" "$target_file"
  # Run post-processing on the copied file
  sh "$(dirname "$0")/build_post_process_yaml.sh" "$target_file" "$ENV_PREFIX"
done

if [ $? -eq 0 ]; then
  if [ -z "$4" ]; then
    mkdir -p "$SNAPSHOT_DIR"
    SNAPSHOT_PATH="$SNAPSHOT_DIR/$SNAPSHOT_NAME"
    printf "%b" "$SNAPSHOT_DATA" > "$SNAPSHOT_PATH"
  fi
  echo "Promoted $BUILD_NAME version $VERSION to environment $ENV_INPUT"
else
  echo "Promotion failed, no snapshot written."
  exit 1
fi
