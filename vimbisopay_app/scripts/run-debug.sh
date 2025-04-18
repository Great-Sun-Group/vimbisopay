#!/bin/bash
#
# VimbisoPay App Debug Run Script
# 
# This script runs the debug version of the app with the correct debug package name.
# The debug version will have the package name com.vimbisopay.vimbisopay_app.debug
# which allows it to be installed alongside the release version.
#
# Usage: ./run-debug.sh [--api-env dev|prod]
#

# Default API environment
API_ENV="dev"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --api-env) API_ENV="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Validate API environment
if [[ "$API_ENV" != "dev" && "$API_ENV" != "prod" ]]; then
    echo "Error: API environment must be 'dev' or 'prod'"
    exit 1
fi

echo "Running debug version with API environment: $API_ENV"

# Set the API environment in the app
if [ "$API_ENV" == "dev" ]; then
    echo "Setting API environment to development"
    # This will be handled by the ApiConfig class which defaults to development for debug builds
elif [ "$API_ENV" == "prod" ]; then
    echo "Setting API environment to production"
    # You could create a temporary file or use a flag to indicate production environment
    # For now, we'll rely on the user to manually change it in the debug screen
    echo "Note: You'll need to change the API environment to Production in the debug screen"
fi

# Run the app in debug mode
flutter run --debug
