#!/bin/bash

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

# Update pubspec.yaml version
sed -i '' "s/version: .*/version: $new_version/" pubspec.yaml

# Collect changes for both CHANGELOG and GitHub release
echo "Enter changes (one per line, press Ctrl+D when done):"
changes=""
while IFS= read -r line; do
    echo "- $line" >> CHANGELOG.md
    changes="${changes}- ${line}\n"
done

# Update CHANGELOG.md
echo -e "\n## [$new_version] - $current_date" >> CHANGELOG.md

echo "Building new APK..."
flutter build apk --release

# Create version-specific APK name
version_apk="build/app/outputs/flutter-apk/vimbisopay-${new_version}.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$version_apk"

# Get current branch name
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Commit changes
echo "Committing version changes..."
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: bump version to $new_version"

# Create and push tag
echo "Creating git tag..."
git tag -a "v$new_version" -m "Release v$new_version"
git push origin "v$new_version"

echo "Creating GitHub release..."

# Create GitHub release
release_response=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$GITHUB_REPO/releases" \
  -d "{
    \"tag_name\":\"v$new_version\",
    \"target_commitish\":\"$current_branch\",
    \"name\":\"Release v$new_version\",
    \"body\":\"$(echo -e "$changes")\",
    \"draft\":false,
    \"prerelease\":false
  }")

# Extract release ID from response
release_id=$(echo "$release_response" | grep -o '"id": [0-9]*' | head -1 | cut -d' ' -f2)

if [ -z "$release_id" ]; then
    echo "Error: Failed to create GitHub release"
    echo "Response: $release_response"
    exit 1
fi

# Upload APK as release asset
echo "Uploading APK to GitHub release..."
curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/octet-stream" \
  "https://uploads.github.com/repos/$GITHUB_REPO/releases/$release_id/assets?name=$(basename "$version_apk")" \
  --data-binary "@$version_apk"

echo "Version updated to $new_version"
echo "APK location: $version_apk"
echo "GitHub release created: https://github.com/$GITHUB_REPO/releases/tag/v$new_version"
echo "Changes have been committed and pushed"
