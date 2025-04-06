#!/bin/bash

# Script to set up Firebase configuration for web from GitHub Secret
# This script should be run during Codespace creation via devcontainer.json

set -e  # Exit immediately if a command exits with a non-zero status

# Check if the FIREBASE_CONFIG environment variable is set
if [ -z "$FIREBASE_CONFIG" ]; then
  echo "Error: FIREBASE_CONFIG environment variable is not set."
  echo "Please add the FIREBASE_CONFIG secret to your GitHub repository."
  exit 1
fi

# Define the target directories and files
WEB_DIR="/workspaces/vimbisopay/vimbisopay_app/web"
LIB_DIR="/workspaces/vimbisopay/vimbisopay_app/lib"
FIREBASE_OPTIONS_FILE="$LIB_DIR/firebase_options.dart"
INDEX_HTML_FILE="$WEB_DIR/index.html"

# Create the web directory if it doesn't exist
mkdir -p "$WEB_DIR"

# Create a basic index.html file if it doesn't exist
if [ ! -f "$INDEX_HTML_FILE" ]; then
  echo "Creating basic index.html file..."
  cat > "$INDEX_HTML_FILE" << 'EOL'
<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">

  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="VimbisoPay Web App">

  <!-- iOS meta tags & icons -->
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="VimbisoPay">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>

  <title>VimbisoPay</title>
  <link rel="manifest" href="manifest.json">

  <script>
    // The value below is injected by flutter build, do not touch.
    var serviceWorkerVersion = null;
  </script>
  <!-- This script adds the flutter initialization JS code -->
  <script src="flutter.js" defer></script>
</head>
<body>
  <script>
    window.addEventListener('load', function(ev) {
      // Download main.dart.js
      _flutter.loader.loadEntrypoint({
        serviceWorker: {
          serviceWorkerVersion: serviceWorkerVersion,
        },
        onEntrypointLoaded: function(engineInitializer) {
          engineInitializer.initializeEngine().then(function(appRunner) {
            appRunner.runApp();
          });
        }
      });
    });
  </script>
</body>
</html>
EOL
fi

# Extract values from FIREBASE_CONFIG
API_KEY=$(echo "$FIREBASE_CONFIG" | grep -o 'apiKey: "[^"]*"' | cut -d'"' -f2)
AUTH_DOMAIN=$(echo "$FIREBASE_CONFIG" | grep -o 'authDomain: "[^"]*"' | cut -d'"' -f2)
PROJECT_ID=$(echo "$FIREBASE_CONFIG" | grep -o 'projectId: "[^"]*"' | cut -d'"' -f2)
STORAGE_BUCKET=$(echo "$FIREBASE_CONFIG" | grep -o 'storageBucket: "[^"]*"' | cut -d'"' -f2)
MESSAGING_SENDER_ID=$(echo "$FIREBASE_CONFIG" | grep -o 'messagingSenderId: "[^"]*"' | cut -d'"' -f2)
APP_ID=$(echo "$FIREBASE_CONFIG" | grep -o 'appId: "[^"]*"' | cut -d'"' -f2)
MEASUREMENT_ID=$(echo "$FIREBASE_CONFIG" | grep -o 'measurementId: "[^"]*"' | cut -d'"' -f2)

# Create a new index.html file with Firebase configuration
echo "Creating index.html file with Firebase configuration..."
cat > "$INDEX_HTML_FILE" << EOL
<!DOCTYPE html>
<html>
<head>
  <base href="\$FLUTTER_BASE_HREF">

  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="VimbisoPay Web App">

  <!-- iOS meta tags & icons -->
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="VimbisoPay">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>

  <title>VimbisoPay</title>
  <link rel="manifest" href="manifest.json">

  <script>
    // The value below is injected by flutter build, do not touch.
    var serviceWorkerVersion = null;
  </script>
  <!-- This script adds the flutter initialization JS code -->
  <script src="flutter.js" defer></script>
  
  <!-- Firebase SDK -->
  <script src="https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js"></script>
  <script src="https://www.gstatic.com/firebasejs/8.10.1/firebase-analytics.js"></script>
  <script>
    // Your web app's Firebase configuration
    // For Firebase JS SDK v7.20.0 and later, measurementId is optional
    var firebaseConfig = {
      apiKey: "$API_KEY",
      authDomain: "$AUTH_DOMAIN",
      projectId: "$PROJECT_ID",
      storageBucket: "$STORAGE_BUCKET",
      messagingSenderId: "$MESSAGING_SENDER_ID",
      appId: "$APP_ID",
      measurementId: "$MEASUREMENT_ID"
    };

    // Initialize Firebase
    firebase.initializeApp(firebaseConfig);
    firebase.analytics();
  </script>
</head>
<body>
  <script>
    window.addEventListener('load', function(ev) {
      // Download main.dart.js
      _flutter.loader.loadEntrypoint({
        serviceWorker: {
          serviceWorkerVersion: serviceWorkerVersion,
        },
        onEntrypointLoaded: function(engineInitializer) {
          engineInitializer.initializeEngine().then(function(appRunner) {
            appRunner.runApp();
          });
        }
      });
    });
  </script>
</body>
</html>
EOL

# Create firebase_options.dart file
echo "Creating firebase_options.dart file..."
mkdir -p "$LIB_DIR"

# Extract values from FIREBASE_CONFIG
API_KEY=$(echo "$FIREBASE_CONFIG" | grep -o 'apiKey: "[^"]*"' | cut -d'"' -f2)
AUTH_DOMAIN=$(echo "$FIREBASE_CONFIG" | grep -o 'authDomain: "[^"]*"' | cut -d'"' -f2)
PROJECT_ID=$(echo "$FIREBASE_CONFIG" | grep -o 'projectId: "[^"]*"' | cut -d'"' -f2)
STORAGE_BUCKET=$(echo "$FIREBASE_CONFIG" | grep -o 'storageBucket: "[^"]*"' | cut -d'"' -f2)
MESSAGING_SENDER_ID=$(echo "$FIREBASE_CONFIG" | grep -o 'messagingSenderId: "[^"]*"' | cut -d'"' -f2)
APP_ID=$(echo "$FIREBASE_CONFIG" | grep -o 'appId: "[^"]*"' | cut -d'"' -f2)
MEASUREMENT_ID=$(echo "$FIREBASE_CONFIG" | grep -o 'measurementId: "[^"]*"' | cut -d'"' -f2)

cat > "$FIREBASE_OPTIONS_FILE" << EOL
// File generated by setup-firebase-config.sh
// Do not edit by hand

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // Add other platforms if needed in the future
    throw UnsupportedError(
      'DefaultFirebaseOptions are not configured for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '$API_KEY',
    appId: '$APP_ID',
    messagingSenderId: '$MESSAGING_SENDER_ID',
    projectId: '$PROJECT_ID',
    authDomain: '$AUTH_DOMAIN',
    storageBucket: '$STORAGE_BUCKET',
    measurementId: '$MEASUREMENT_ID',
  );
}
EOL

# Verify the files were created
if [ -f "$INDEX_HTML_FILE" ] && [ -f "$FIREBASE_OPTIONS_FILE" ]; then
  echo "Successfully created Firebase configuration files:"
  echo "- $INDEX_HTML_FILE"
  echo "- $FIREBASE_OPTIONS_FILE"
  echo "Firebase configuration for web has been set up."
else
  echo "Error: Failed to create Firebase configuration files"
  exit 1
fi

# Set appropriate permissions
chmod 644 "$INDEX_HTML_FILE"
chmod 644 "$FIREBASE_OPTIONS_FILE"
echo "Set appropriate permissions on configuration files"

echo "Firebase web setup complete."
