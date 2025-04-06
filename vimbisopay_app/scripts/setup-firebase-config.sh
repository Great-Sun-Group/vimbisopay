#!/bin/bash

# Script to set up Firebase configuration from GitHub Secret
# This script should be run during Codespace creation via devcontainer.json

set -e  # Exit immediately if a command exits with a non-zero status

# Check if the FIREBASE_CONFIG environment variable is set
if [ -z "$FIREBASE_CONFIG" ]; then
  echo "Error: FIREBASE_CONFIG environment variable is not set."
  echo "Please add the FIREBASE_CONFIG secret to your GitHub repository."
  exit 1
fi

# Define the target directory and file
TARGET_DIR="/workspaces/vimbisopay/vimbisopay_app/android/app"
TARGET_FILE="$TARGET_DIR/google-services.json"

# Create the directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Write the config to the file
echo "$FIREBASE_CONFIG" > "$TARGET_FILE"

# Verify the file was created
if [ -f "$TARGET_FILE" ]; then
  echo "Successfully created $TARGET_FILE"
  # Don't print the contents as it contains sensitive information
  echo "Firebase configuration has been set up."
else
  echo "Error: Failed to create $TARGET_FILE"
  exit 1
fi

# Set appropriate permissions
chmod 600 "$TARGET_FILE"
echo "Set secure permissions on $TARGET_FILE"

echo "Firebase setup complete."
