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
    
    # Remove any existing API environment flag file
    if [ -f ".api_env_prod" ]; then
        rm .api_env_prod
        echo "Removed production environment flag file"
    fi
elif [ "$API_ENV" == "prod" ]; then
    echo "Setting API environment to production"
    # Create a temporary file to indicate production environment
    # This file will be detected by the app on startup
    touch .api_env_prod
    echo "API environment will be automatically set to Production on app startup"
fi

# Ensure that direct flutter run commands will use development environment
# by adding a cleanup trap
trap 'if [ -f ".api_env_prod" ]; then rm .api_env_prod; echo "Cleaned up production environment flag file"; fi' EXIT

# Run the app in debug mode
flutter run --debug
