#!/bin/bash
#
# VimbisoPay App Debug Version Update Script
# 
# This script automates the process of updating the debug app version and uploading to GitHub:
# - Updates the version in pubspec.yaml with debug suffix
# - Updates the version in android/local.properties for Android builds
# - Builds a new debug APK with the updated version
# - Creates a Git tag and GitHub release with the debug version
#
# Usage: ./update-debug-version.sh [--api-env dev|prod]
#

# Default values
API_ENV="dev"
UPDATE_PRIORITY="low"
UPDATE_TYPE="patch"
MIN_REQUIRED_VERSION=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --api-env) API_ENV="$2"; shift ;;
        --priority) UPDATE_PRIORITY="$2"; shift ;;
        --type) UPDATE_TYPE="$2"; shift ;;
        --min-version) MIN_REQUIRED_VERSION="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Validate API environment
if [[ "$API_ENV" != "dev" && "$API_ENV" != "prod" ]]; then
    echo "Error: API environment must be 'dev' or 'prod'"
    exit 1
fi

# Validate update priority
if [[ ! "$UPDATE_PRIORITY" =~ ^(low|medium|high|critical)$ ]]; then
    echo "Warning: Invalid update priority. Using 'low'."
    UPDATE_PRIORITY="low"
fi

# Validate update type
if [[ ! "$UPDATE_TYPE" =~ ^(patch|minor|major)$ ]]; then
    echo "Warning: Invalid update type. Using 'patch'."
    UPDATE_TYPE="patch"
fi

# URL encoding function
urlencode() {
  local string="$1"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
    c=${string:$pos:1}
    case "$c" in
      [-_.~a-zA-Z0-9] ) o="${c}" ;;
      "+" )             o="%2B" ;;
      * )               printf -v o '%%%02x' "'$c"
    esac
    encoded+="${o}"
  done
  echo "${encoded}"
}

# Source GitHub configuration
source "$(dirname "$0")/github_config.sh"

if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_REPO" ]; then
    echo "Error: GitHub configuration not found or incomplete"
    exit 1
fi

# Get current date
current_date=$(date +%Y-%m-%d)

# Read current version from pubspec.yaml
current_version=$(grep "version:" pubspec.yaml | cut -d' ' -f2)

echo "Current version: $current_version"
echo "Enter new debug version (format: x.y.z+b):"
read new_version

# Validate version format
if ! [[ $new_version =~ ^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$ ]]; then
  echo "Error: Invalid version format. Expected format is x.y.z or x.y.z+b where x, y, z, and b are numbers."
  echo "Example: 1.0.0 or 1.0.0+49"
  exit 1
fi

# Parse version components
version_name=$(echo $new_version | cut -d'+' -f1)
version_code=$(echo $new_version | cut -d'+' -f2)

# Check if version code is missing (no + in the version string)
if [ "$version_name" = "$version_code" ]; then
  echo "Warning: No version code provided in the version string."
  echo "Using current version code from local.properties..."
  
  # Try to get current version code from local.properties
  if [ -f "android/local.properties" ]; then
    current_code=$(grep "flutter.versionCode" "android/local.properties" | cut -d'=' -f2)
    if [ -n "$current_code" ]; then
      # Increment the current version code
      version_code=$((current_code + 1))
      echo "Incremented version code to: $version_code"
      # Update the new_version to include the version code
      new_version="${version_name}+${version_code}"
      echo "Updated full version to: $new_version"
    else
      # Default to 1 if no current version code found
      version_code=1
      echo "No current version code found, defaulting to: $version_code"
      # Update the new_version to include the version code
      new_version="${version_name}+${version_code}"
      echo "Updated full version to: $new_version"
    fi
  else
    # Default to 1 if local.properties doesn't exist
    version_code=1
    echo "No local.properties file found, defaulting version code to: $version_code"
    # Update the new_version to include the version code
    new_version="${version_name}+${version_code}"
    echo "Updated full version to: $new_version"
  fi
else
  echo "Version name: $version_name"
  echo "Version code: $version_code"
fi

# Add debug suffix to version name
debug_version_name="${version_name}-debug"
debug_version="${debug_version_name}+${version_code}"

# Create filename-safe version for APK filenames (replace + with -)
filename_version="${debug_version/+/-}"

# Create tag name with debug prefix that matches the filename format
tag_name="debug-v${version_name}-debug-${version_code}"

# Create URL-safe version for GitHub release URL using proper URL encoding
url_safe_version=$(urlencode "$debug_version")

echo "Debug version: $debug_version"
echo "Tag name: $tag_name"
echo "Filename version: $filename_version"

# Update pubspec.yaml version
sed -i '' "s/version: .*/version: $debug_version/" pubspec.yaml

# Update Android local.properties with new version
if [ -f "android/local.properties" ]; then
  # Set build mode to debug
  if grep -q "flutter.buildMode" "android/local.properties"; then
    sed -i '' "s/flutter.buildMode=.*/flutter.buildMode=debug/" "android/local.properties"
  else
    echo "flutter.buildMode=debug" >> "android/local.properties"
  fi
  
  # Update version name and code
  if grep -q "flutter.versionName" "android/local.properties"; then
    sed -i '' "s/flutter.versionName=.*/flutter.versionName=$debug_version_name/" "android/local.properties"
  else
    echo "flutter.versionName=$debug_version_name" >> "android/local.properties"
  fi
  
  if grep -q "flutter.versionCode" "android/local.properties"; then
    sed -i '' "s/flutter.versionCode=.*/flutter.versionCode=$version_code/" "android/local.properties"
  else
    echo "flutter.versionCode=$version_code" >> "android/local.properties"
  fi
  
  echo "Updated Android version in local.properties"
else
  echo "Warning: android/local.properties not found, Android version not updated"
fi

# Update CHANGELOG.md
echo -e "\n## [$debug_version] - $current_date (Debug Build)" >> CHANGELOG.md
echo "- Debug build with API environment: $API_ENV" >> CHANGELOG.md

# Collect changes for both CHANGELOG and GitHub release
echo "Enter changes (one per line, press Ctrl+D when done):"
changes=""
while IFS= read -r line; do
    echo "- $line" >> CHANGELOG.md
    changes="${changes}- ${line}\n"
done

# Build universal debug APK
echo "Building universal debug APK..."
flutter build apk --debug

# Add a delay to ensure the APK is fully written
sleep 5

# Locate the debug APK file
apk_path="build/app/outputs/flutter-apk/app-debug.apk"
if [ ! -f "$apk_path" ]; then
    echo "Error: Debug APK not found at $apk_path"
    exit 1
fi

echo "Found universal debug APK at: $apk_path"

# Create version-specific APK name for debug APK
version_apk="build/app/outputs/flutter-apk/vimbisopay-${filename_version}.apk"

# Create version-specific copy
echo "Copying universal debug APK to version-specific location..."
cp "$apk_path" "$version_apk"

# Verify copy was successful
if [ ! -f "$version_apk" ]; then
    echo "Error: Failed to create version-specific APK at $version_apk"
    exit 1
fi

# Build architecture-specific APKs
echo "Building architecture-specific debug APKs..."
flutter build apk --debug --split-per-abi

# Add a delay to ensure the APKs are fully written
sleep 5

# Define architecture-specific APK paths
arm64_apk="build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk"
arm_apk="build/app/outputs/flutter-apk/app-armeabi-v7a-debug.apk"
x86_64_apk="build/app/outputs/flutter-apk/app-x86_64-debug.apk"

# Create version-specific copies for architecture-specific APKs
version_arm64_apk="build/app/outputs/flutter-apk/vimbisopay-${filename_version}-arm64.apk"
version_arm_apk="build/app/outputs/flutter-apk/vimbisopay-${filename_version}-arm.apk"
version_x86_64_apk="build/app/outputs/flutter-apk/vimbisopay-${filename_version}-x86_64.apk"

# Copy architecture-specific APKs to version-specific locations
echo "Copying architecture-specific APKs to version-specific locations..."
cp "$arm64_apk" "$version_arm64_apk"
cp "$arm_apk" "$version_arm_apk"
cp "$x86_64_apk" "$version_x86_64_apk"

# Verify copies were successful
if [ ! -f "$version_arm64_apk" ] || [ ! -f "$version_arm_apk" ] || [ ! -f "$version_x86_64_apk" ]; then
    echo "Error: Failed to create one or more version-specific architecture APKs"
    exit 1
fi

# Generate checksums for all APKs
echo "Generating checksums..."
checksum_universal=$(shasum -a 256 "$version_apk" | awk '{print $1}')
checksum_arm64=$(shasum -a 256 "$version_arm64_apk" | awk '{print $1}')
checksum_arm=$(shasum -a 256 "$version_arm_apk" | awk '{print $1}')
checksum_x86_64=$(shasum -a 256 "$version_x86_64_apk" | awk '{print $1}')

# Create checksums file
checksums_file="build/app/outputs/flutter-apk/vimbisopay-${filename_version}-checksums.txt"
echo "Creating checksums file at $checksums_file..."
echo "vimbisopay-${filename_version}.apk: $checksum_universal" > "$checksums_file"
echo "vimbisopay-${filename_version}-arm64.apk: $checksum_arm64" >> "$checksums_file"
echo "vimbisopay-${filename_version}-arm.apk: $checksum_arm" >> "$checksums_file"
echo "vimbisopay-${filename_version}-x86_64.apk: $checksum_x86_64" >> "$checksums_file"

# Prompt for minimum required version if not provided
if [ -z "$MIN_REQUIRED_VERSION" ]; then
    echo "Enter minimum required version (format: x.y.z):"
    read MIN_REQUIRED_VERSION
    
    # Validate minimum required version format
    if ! [[ $MIN_REQUIRED_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid minimum required version format. Expected format is x.y.z where x, y, and z are numbers."
        echo "Example: 1.9.0"
        exit 1
    fi
fi

# Create apk-builds directory if it doesn't exist
mkdir -p apk-builds

# Get current branch name
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Commit changes
echo "Committing version changes..."
git add pubspec.yaml CHANGELOG.md android/local.properties
git commit -m "chore: bump debug version to $debug_version"

# Push commit
echo "Pushing commit..."
if ! git push origin "$current_branch"; then
    echo "Error: Failed to push commit"
    exit 1
fi

# Create and push tag
echo "Creating git tag..."
# Check if tag already exists locally
if git rev-parse "$tag_name" >/dev/null 2>&1; then
    echo "Tag $tag_name already exists locally. Deleting..."
    git tag -d "$tag_name"
fi

# Check if tag exists on remote
if git ls-remote --tags origin | grep -q "refs/tags/$tag_name$"; then
    echo "Tag $tag_name exists on remote. Deleting..."
    git push --delete origin "$tag_name" || {
        echo "Error: Failed to delete remote tag"
        exit 1
    }
fi

# Create new tag
git tag -a "$tag_name" -m "Debug Release $debug_version"
if ! git push origin "$tag_name"; then
    echo "Error: Failed to push tag"
    exit 1
fi

# Wait for tag to be available on GitHub
echo "Waiting for tag to be available on GitHub..."
sleep 5

# Verify tag exists on remote
if ! git ls-remote --tags origin | grep -q "refs/tags/$tag_name$"; then
    echo "Error: Tag $tag_name not found on remote"
    exit 1
fi

echo "Creating GitHub release..."

# Create GitHub release
release_response=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$GITHUB_REPO/releases" \
  -d "{
    \"tag_name\":\"$tag_name\",
    \"target_commitish\":\"$current_branch\",
    \"name\":\"Debug Release $debug_version\",
    \"body\":\"Debug build with API environment: $API_ENV\n$(echo -e "$changes" | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n')\",
    \"draft\":false,
    \"prerelease\":true
  }")

# Extract release ID from response
release_id=$(echo "$release_response" | grep -o '"id": [0-9]*' | head -1 | cut -d' ' -f2)

if [ -z "$release_id" ]; then
    echo "Error: Failed to create GitHub release"
    # Try to extract error message from response
    error_message=$(echo "$release_response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$error_message" ]; then
        echo "Error message: $error_message"
    fi
    echo "Full response: $release_response"
    exit 1
fi

# Verify APK exists before upload
if [ ! -f "$version_apk" ]; then
    echo "Error: APK file not found at $version_apk"
    exit 1
fi

# Define GitHub download base URL
github_download_base="https://github.com/$GITHUB_REPO/releases/download/$tag_name"

# Create clean version for JSON (without -debug suffix)
json_version="${version_name}+${version_code}"

# Create JSON file with version information
json_file="apk-builds/vimbisopay-${debug_version}.json"
echo "Creating version JSON file at $json_file..."
cat > "$json_file" << EOF
{
  "appId": "com.vimbisopay.vimbisopay_app.debug",
  "platform": "android",
  "version": "$json_version",
  "minRequiredVersion": "$MIN_REQUIRED_VERSION",
  "updateUrl": "$github_download_base/$(basename "$version_apk")",
  "fileSizeBytes": $(stat -f%z "$version_apk"),
  "releaseNotes": "Debug build with API environment: $API_ENV\n$(echo -e "$changes" | sed 's/"/\\"/g' | tr '\n' ' ')",
  "releaseDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "updatePriority": "$UPDATE_PRIORITY",
  "updateType": "$UPDATE_TYPE",
  "active": true,
  "checksumAlgorithm": "sha256",
  "checksumUniversal": "$checksum_universal",
  "checksumArm64": "$checksum_arm64",
  "checksumArm": "$checksum_arm",
  "checksumX86_64": "$checksum_x86_64",
  "checksumUrl": "$github_download_base/$(basename "$checksums_file")",
  "architectureSpecificDownloads": {
    "arm64-v8a": "$github_download_base/$(basename "$version_arm64_apk")",
    "armeabi-v7a": "$github_download_base/$(basename "$version_arm_apk")",
    "x86_64": "$github_download_base/$(basename "$version_x86_64_apk")"
  },
  "buildType": "debug",
  "apiEnvironment": "$API_ENV"
}
EOF

# Upload universal debug APK as release asset
echo "Uploading universal debug APK to GitHub release..."
echo "Using APK file: $version_apk"
upload_response=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/octet-stream" \
  "https://uploads.github.com/repos/$GITHUB_REPO/releases/$release_id/assets?name=$(basename "$version_apk")" \
  --data-binary "@$version_apk")

# Check if upload was successful
if ! echo "$upload_response" | grep -q '"state":"uploaded"'; then
    echo "Error: Failed to upload universal debug APK"
    # Try to extract error message from response
    error_message=$(echo "$upload_response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$error_message" ]; then
        echo "Error message: $error_message"
    fi
    echo "Full response: $upload_response"
    exit 1
fi

# Upload architecture-specific APKs
echo "Uploading architecture-specific APKs to GitHub release..."
for arch_apk in "$version_arm64_apk" "$version_arm_apk" "$version_x86_64_apk"; do
    echo "Uploading: $arch_apk"
    arch_upload_response=$(curl -L \
      -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/octet-stream" \
      "https://uploads.github.com/repos/$GITHUB_REPO/releases/$release_id/assets?name=$(basename "$arch_apk")" \
      --data-binary "@$arch_apk")
    
    # Check if upload was successful
    if ! echo "$arch_upload_response" | grep -q '"state":"uploaded"'; then
        echo "Error: Failed to upload architecture-specific APK: $arch_apk"
        # Try to extract error message from response
        error_message=$(echo "$arch_upload_response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$error_message" ]; then
            echo "Error message: $error_message"
        fi
        echo "Full response: $arch_upload_response"
        # Continue with other uploads even if one fails
    fi
done

# Upload checksums file
echo "Uploading checksums file to GitHub release..."
checksums_upload_response=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/octet-stream" \
  "https://uploads.github.com/repos/$GITHUB_REPO/releases/$release_id/assets?name=$(basename "$checksums_file")" \
  --data-binary "@$checksums_file")

# Check if upload was successful
if ! echo "$checksums_upload_response" | grep -q '"state":"uploaded"'; then
    echo "Error: Failed to upload checksums file"
    # Try to extract error message from response
    error_message=$(echo "$checksums_upload_response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$error_message" ]; then
        echo "Error message: $error_message"
    fi
    echo "Full response: $checksums_upload_response"
    # Continue even if this upload fails
fi

# Upload JSON file
echo "Uploading version JSON file to GitHub release..."
json_upload_response=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/octet-stream" \
  "https://uploads.github.com/repos/$GITHUB_REPO/releases/$release_id/assets?name=$(basename "$json_file")" \
  --data-binary "@$json_file")

# Check if upload was successful
if ! echo "$json_upload_response" | grep -q '"state":"uploaded"'; then
    echo "Error: Failed to upload version JSON file"
    # Try to extract error message from response
    error_message=$(echo "$json_upload_response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$error_message" ]; then
        echo "Error message: $error_message"
    fi
    echo "Full response: $json_upload_response"
    # Continue even if this upload fails
fi

echo "Debug version updated to $debug_version"
echo "API Environment: $API_ENV"
echo "APK location: $version_apk"
echo "Version JSON file: $json_file"
echo "GitHub release created: https://github.com/$GITHUB_REPO/releases/tag/$tag_name"
echo "Download URL: $github_download_base/$(basename "$version_apk")"
echo "Changes have been committed and pushed"
