
# Usage: build_create_release.sh <build_name> <version_yaml_file> <yaml_directory>

# Determine the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#
# Creates a new build version directory, copies YAMLs, updates versioning, and ensures Kubernetes metadata is correct.
#
# Arguments:
#   <build_name>         Name of the build/service (used as the build directory name)
#   <version_yaml_file>  Path to YAML file containing 'major:' and 'minor:' version fields
#   <yaml_directory>     Directory containing the YAML files to be versioned
#
# Example:
#   ./build_create_release.sh myservice version.yaml ./yamls
#
# This will:
#   - Read major/minor from version.yaml
#   - Create a new version directory under builds/myservice/<major>.<minor>.<build>
#   - Copy all YAMLs from ./yamls into the new version directory
#   - Update deployment.yaml image tag and all metadata labels/annotations with the new version
#
# Logical Environment Placeholders:
#   To target multiple logical environments within a single Kubernetes cluster, you can use placeholders in your YAML files:
#
#   [LogicalEnvironmentInsertBefore=some-text]
#     - Inserts the environment prefix before every occurrence of 'some-text' on that line.
#     - Example: If ENV_PREFIX is 'test', and the line is:
#         app: my-frontend # [LogicalEnvironmentInsertBefore=my-frontend] This is the name of my frontend
#       The result will be:
#         app: test-my-frontend # This is the name of my frontend
#
#   [LogicalEnvironmentInsertAfter=some-text]
#     - Inserts the environment prefix after every occurrence of 'some-text' on that line.
#     - Example: If ENV_PREFIX is 'test', and the line is:
#         app: my-frontend  # [LogicalEnvironmentInsertAfter=my-frontend]
#       The result will be:
#         app: my-frontend-test
#
#   After processing, the placeholders will be removed from the YAML file, and any empty comments will be cleaned up.
#
#   This allows you to use a single YAML source to generate environment-specific resources for multiple logical environments.


if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <build_name> <version_yaml_file> <yaml_directory>"
  echo
  echo "Creates a new build version directory, copies YAMLs, updates versioning, and ensures Kubernetes metadata is correct."
  echo
  echo "Arguments:"
  echo "  <build_name>         Name of the build/service (used as the build directory name)"
  echo "  <version_yaml_file>  Path to YAML file containing 'major:' and 'minor:' version fields"
  echo "  <yaml_directory>     Directory containing the YAML files to be versioned"
  echo
  echo "Example:"
  echo "  $0 myservice version.yaml /my_yamls_directory"
  echo
  echo "This will:"
  echo "  - Read major/minor from version.yaml"
  echo "  - Create a new version directory under builds/myservice/<major>.<minor>.<build>"
  echo "  - Copy all YAMLs from ./yamls into the new version directory"
  echo "  - Update deployment.yaml image tag and all metadata labels/annotations with the new version"
  echo
  echo "Logical Environment Placeholders:"
  echo "  To target multiple logical environments within a single Kubernetes cluster, you can use placeholders in your YAML files:"
  echo
  echo "  [LogicalEnvironmentInsertBefore=some-text]"
  echo "    - Inserts the environment prefix before every occurrence of 'some-text' on that line."
  echo "    - Example: If ENV_PREFIX is 'test', and the line is:"
  echo "        app: my-frontend # [LogicalEnvironmentInsertBefore=my-frontend] This is the name of my fronten"
  echo "      The result will be:"
  echo "        app: test-my-frontend # This is the name of my fronten"
  echo
  echo "  [LogicalEnvironmentInsertAfter=some-text]"
  echo "    - Inserts the environment prefix after every occurrence of 'some-text' on that line."
  echo "    - Example: If ENV_PREFIX is 'test', and the line is:"
  echo "        app: my-frontend  # [LogicalEnvironmentInsertAfter=my-frontend] This is the name of my frontend"
  echo "      The result will be:"
  echo "        app: my-frontend-test # This is the name of my frontend"
  echo
  echo "  After processing, the placeholders will be removed from the YAML file, and any empty comments will be cleaned up."
  echo
  echo "  This allows you to use a single YAML source to generate environment-specific resources for multiple logical environments."
  exit 1
fi

NAME="$1"
VERSION_YAML_FILE="$2"
YAML_DIRECTORY="$3"
BUILDS_DIR="$SCRIPT_DIR/../builds"
BUILD_DIR="$BUILDS_DIR/$NAME"

# Parse major and minor version from version YAML file
if [ ! -f "$VERSION_YAML_FILE" ]; then
  echo "Version YAML file not found: $VERSION_YAML_FILE"
  exit 1
fi



# Extract and clean major and minor version values
MAJOR=$(grep '^major:' "$VERSION_YAML_FILE" | awk '{print $2}' | tr -d '\r')
MINOR=$(grep '^minor:' "$VERSION_YAML_FILE" | awk '{print $2}' | tr -d '\r')

# Ensure major and minor are numeric (POSIX compatible)
case "$MAJOR" in
  ''|*[!0-9]*) echo "Error: major version '$MAJOR' is not numeric. Aborting"; exit 1 ;;
esac
case "$MINOR" in
  ''|*[!0-9]*) echo "Error: minor version '$MINOR' is not numeric. Aborting"; exit 1 ;;
esac

# Initialize the build directory if it doesn't exist
if [ ! -d "$BUILDS_DIR" ]; then
  mkdir -p "$BUILDS_DIR"
fi
if [ ! -d "$BUILD_DIR" ]; then
  mkdir -p "$BUILD_DIR"
fi

# Determine the new build number
BUILD_NUMBER_FILE="$BUILD_DIR/build.number"
if [ -f "$BUILD_NUMBER_FILE" ]; then
  CURRENT_BUILD_NUMBER=$(cat "$BUILD_NUMBER_FILE")
  NEW_BUILD_NUMBER=$((CURRENT_BUILD_NUMBER + 1))
else
  NEW_BUILD_NUMBER=0
fi


# Compose the full version number
FULL_VERSION="$MAJOR.$MINOR.$NEW_BUILD_NUMBER"

# Create the new version directory
VERSION_DIR="$BUILD_DIR/$FULL_VERSION"
if [ -d "$VERSION_DIR" ]; then
  echo "Error: Version directory $VERSION_DIR already exists. Aborting"
  exit 1
fi
mkdir -p "$VERSION_DIR"

# Copy all files from the specified yaml_directory to the new version directory
# recusively to capture subdirectories as well that are environment overrides
if [ -d "$YAML_DIRECTORY" ]; then
  cp -a "$YAML_DIRECTORY"/. "$VERSION_DIR"/
else
  echo "YAML directory $YAML_DIRECTORY does not exist. Aborting"
  exit 1
fi

# Update all deployment.yaml image tags to use the new version (recursively)
find "$VERSION_DIR" -type f -name "deployment.yaml" | while read -r depfile; do
  sed -i "s/:latest/:$FULL_VERSION/g" "$depfile"
done


# Ensure all .yaml files in the version directory and subdirectories have correct metadata.labels.version 
# and metadata.annotations.app.kubernetes.io/version
# Ensure labels always come before annotations under metadata

# Improved awk: preserve all metadata children, only update/add version label and app.kubernetes.io/version annotation
find "$VERSION_DIR" -type f -name "*.yaml" | while read -r yamlfile; do
  awk -v version="$FULL_VERSION" '
    BEGIN {inmeta=0; meta_lines=""; before_meta=1; after_meta=0}
    function flush_meta() {
      if (meta_lines != "") {
        sub(/\n*$/, "", meta_lines)
        n = split(meta_lines, arr, "\n")
        labels_start=0; labels_end=0; annotations_start=0; annotations_end=0
        version_found=0; appver_found=0
        # Find blocks
        for (i=1; i<=n; i++) {
          if (arr[i] ~ /^  labels:/) { labels_start=i; labels_end=i }
          if (labels_start && i>labels_start && arr[i] ~ /^    /) labels_end=i
          if (labels_start && i>labels_start && arr[i] !~ /^    / && i>labels_end) break
        }
        for (i=1; i<=n; i++) {
          if (arr[i] ~ /^  annotations:/) { annotations_start=i; annotations_end=i }
          if (annotations_start && i>annotations_start && arr[i] ~ /^    /) annotations_end=i
          if (annotations_start && i>annotations_start && arr[i] !~ /^    / && i>annotations_end) break
        }
        # Print everything, but update/add version/app.kubernetes.io/version
        for (i=1; i<=n; i++) {
          # labels block
          if (i==labels_start) {
            print arr[i]
            for (j=labels_start+1; j<=labels_end; j++) {
              if (arr[j] ~ /^    version:/) {
                print "    version: \""version"\""; version_found=1
              } else {
                print arr[j]
              }
            }
            if (!version_found) print "    version: \""version"\""
            i=labels_end
            continue
          }
          # annotations block
          if (i==annotations_start) {
            print arr[i]
            for (j=annotations_start+1; j<=annotations_end; j++) {
              if (arr[j] ~ /^    app.kubernetes.io\/version:/) {
                print "    app.kubernetes.io/version: \""version"\""; appver_found=1
              } else {
                print arr[j]
              }
            }
            if (!appver_found) print "    app.kubernetes.io/version: \""version"\""
            i=annotations_end
            continue
          }
          # print all other lines
          if ((i<labels_start || i>labels_end) && (i<annotations_start || i>annotations_end)) {
            print arr[i]
          }
        }
        # If no labels block, add it
        if (!labels_start) {
          print "  labels:"; print "    version: \""version"\""
        }
        # If no annotations block, add it
        if (!annotations_start) {
          print "  annotations:"; print "    app.kubernetes.io/version: \""version"\""
        }
      }
    }
    /^metadata:/ {inmeta=1; before_meta=0; print; next}
    inmeta && /^[^ ]/ {flush_meta(); inmeta=0; after_meta=1; print}
    inmeta {meta_lines = meta_lines $0 "\n"; next}
    before_meta {print}
    after_meta {print}
    END {if (inmeta) flush_meta()}
  ' "$yamlfile" > "$yamlfile.tmp" && mv "$yamlfile.tmp" "$yamlfile"
done

# Update the build.number file
echo "$NEW_BUILD_NUMBER" > "$BUILD_NUMBER_FILE"

# Print success message
echo "$FULL_VERSION"