#!/bin/bash
#
# VimbisoPay App Version Update Script
# 
# This script automates the process of updating the app version across all necessary files:
# - Updates the version in pubspec.yaml
# - Updates the version in android/local.properties for Android builds
# - Updates the CHANGELOG.md with the new version and release notes
# - Builds a new APK with the updated version
# - Creates a Git tag and GitHub release with the new version
#
# The script ensures that both the version name (x.y.z) and version code (build number)
# are properly synchronized between Flutter and Android.
#
# Usage: ./update-version.sh
#
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
echo "Enter new version (format: x.y.z+b):"
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

# Update pubspec.yaml version
sed -i '' "s/version: .*/version: $new_version/" pubspec.yaml

# Update Android local.properties with new version
if [ -f "android/local.properties" ]; then
  # Check if properties already exist and update them
  if grep -q "flutter.versionName" "android/local.properties"; then
    sed -i '' "s/flutter.versionName=.*/flutter.versionName=$version_name/" "android/local.properties"
  else
    echo "flutter.versionName=$version_name" >> "android/local.properties"
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
echo -e "\n## [$new_version] - $current_date" >> CHANGELOG.md

# Collect changes for both CHANGELOG and GitHub release
echo "Enter changes (one per line, press Ctrl+D when done):"
changes=""
while IFS= read -r line; do
    echo "- $line" >> CHANGELOG.md
    changes="${changes}- ${line}\n"
done

echo "Building new APK..."
flutter build apk --release

# Add a delay to ensure the APK is fully written
sleep 5

# Locate the APK file
apk_path="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$apk_path" ]; then
    # Try alternative path (sometimes it's in a different location)
    apk_path=$(ls build/app/outputs/flutter-apk/app*.apk 2>/dev/null | head -n 1)
fi

if [ -z "$apk_path" ] || [ ! -f "$apk_path" ]; then
    echo "Error: Release APK not found. Search paths:"
    echo "1. build/app/outputs/flutter-apk/app-release.apk"
    echo "2. build/app/outputs/flutter-apk/app*.apk"
    exit 1
fi

echo "Found APK at: $apk_path"

# Verify file exists and is readable
if [ ! -r "$apk_path" ]; then
    echo "Error: APK file is not readable at $apk_path"
    exit 1
fi

# Create version-specific APK name
version_apk="build/app/outputs/flutter-apk/vimbisopay-${new_version}.apk"

# Create version-specific copy
echo "Copying APK to version-specific location..."
cp "$apk_path" "$version_apk"

# Verify copy was successful
if [ ! -f "$version_apk" ]; then
    echo "Error: Failed to create version-specific APK at $version_apk"
    exit 1
fi

# Verify file exists and is readable
if [ ! -r "$version_apk" ]; then
    echo "Error: Version-specific APK is not readable at $version_apk"
    exit 1
fi

# Get current branch name
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Commit changes
echo "Committing version changes..."
git add pubspec.yaml CHANGELOG.md android/local.properties
git commit -m "chore: bump version to $new_version"

# Push commit
echo "Pushing commit..."
if ! git push origin "$current_branch"; then
    echo "Error: Failed to push commit"
    exit 1
fi

# Create and push tag
echo "Creating git tag..."
# Check if tag already exists locally
if git rev-parse "v$new_version" >/dev/null 2>&1; then
    echo "Tag v$new_version already exists locally. Deleting..."
    git tag -d "v$new_version"
fi

# Check if tag exists on remote
if git ls-remote --tags origin | grep -q "refs/tags/v$new_version$"; then
    echo "Tag v$new_version exists on remote. Deleting..."
    git push --delete origin "v$new_version" || {
        echo "Error: Failed to delete remote tag"
        exit 1
    }
fi

# Create new tag
git tag -a "v$new_version" -m "Release v$new_version"
if ! git push origin "v$new_version"; then
    echo "Error: Failed to push tag"
    exit 1
fi

# Wait for tag to be available on GitHub
echo "Waiting for tag to be available on GitHub..."
sleep 5

# Verify tag exists on remote
if ! git ls-remote --tags origin | grep -q "refs/tags/v$new_version$"; then
    echo "Error: Tag v$new_version not found on remote"
    exit 1
fi

echo "Creating GitHub release..."

# Create GitHub release
release_response=$(curl -L -v \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$GITHUB_REPO/releases" \
  -d "{
    \"tag_name\":\"v$new_version\",
    \"target_commitish\":\"$current_branch\",
    \"name\":\"Release v$new_version\",
    \"body\":\"$(echo -e "$changes" | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n')\",
    \"draft\":false,
    \"prerelease\":false
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
    # Try to extract validation errors
    validation_errors=$(echo "$release_response" | grep -o '"errors":\[[^]]*\]' | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$validation_errors" ]; then
        echo "Validation errors:"
        echo "$validation_errors"
    fi
    echo "Full response: $release_response"
    exit 1
fi

# Verify APK exists before upload
if [ ! -f "$version_apk" ]; then
    echo "Error: APK file not found at $version_apk"
    exit 1
fi

# Verify file exists and is readable
if [ ! -r "$version_apk" ]; then
    echo "Error: APK file is not readable at $version_apk"
    exit 1
fi

# Upload APK as release asset
echo "Uploading APK to GitHub release..."
echo "Using APK file: $version_apk"
upload_response=$(curl -L -v \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/octet-stream" \
  "https://uploads.github.com/repos/$GITHUB_REPO/releases/$release_id/assets?name=$(basename "$version_apk")" \
  --data-binary "@$version_apk")

# Check if upload was successful
if ! echo "$upload_response" | grep -q '"state":"uploaded"'; then
    echo "Error: Failed to upload APK"
    # Try to extract error message from response
    error_message=$(echo "$upload_response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$error_message" ]; then
        echo "Error message: $error_message"
    fi
    echo "Full response: $upload_response"
    exit 1
fi

echo "Version updated to $new_version"
echo "APK location: $version_apk"
echo "GitHub release created: https://github.com/$GITHUB_REPO/releases/tag/v$new_version"
echo "APK download URL: https://github.com/$GITHUB_REPO/releases/download/v$new_version/$(basename "$version_apk")"
echo "Changes have been committed and pushed"
