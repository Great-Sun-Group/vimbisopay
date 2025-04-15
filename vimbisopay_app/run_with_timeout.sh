#!/bin/bash

# Script to run Flutter app with increased build timeout
# Usage: ./run_with_timeout.sh [device_id]

# Default device ID if not provided
DEVICE_ID=${1:-"127.0.0.1:6555"}

# Run Flutter with increased build timeout (5 minutes = 300 seconds)
flutter run --build-timeout=300 -d $DEVICE_ID

echo "Flutter app started with increased build timeout"
