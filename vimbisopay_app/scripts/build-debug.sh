#!/bin/bash

# Exit on error
set -e

# Create artifacts directory if it doesn't exist
mkdir -p artifacts

echo "Building debug artifacts..."

# Build Android debug APK
echo "Building Android debug APK..."
flutter build apk --debug
cp build/app/outputs/flutter-apk/app-debug.apk artifacts/

# Build iOS debug IPA
echo "Building iOS debug app..."
flutter build ios --debug --no-codesign
mkdir -p artifacts/ios_debug
cp -r build/ios/iphonesimulator artifacts/ios_debug/

echo "Debug artifacts built successfully!"
echo "Artifacts location:"
echo "- Android APK: artifacts/app-debug.apk"
echo "- iOS Debug: artifacts/ios_debug/iphonesimulator"
