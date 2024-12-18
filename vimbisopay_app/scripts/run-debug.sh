#!/bin/bash

# Default values
TAG=""

# Function to display usage
show_help() {
    echo "Usage: $0 [-t|--tag TAG] [flutter_args...]"
    echo
    echo "Options:"
    echo "  -t, --tag TAG    Filter logs by specified TAG"
    echo "  -h, --help       Show this help message"
    echo
    echo "Examples:"
    echo "  $0                           # Run with all logs"
    echo "  $0 -t STATE                  # Filter logs with STATE tag"
    echo "  $0 --tag ERROR               # Filter logs with ERROR tag"
    echo "  $0 -t LIFECYCLE -d chrome    # Filter LIFECYCLE logs and run on Chrome"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Run Flutter with debug flags
if [ -n "$TAG" ]; then
    # If TAG is specified, filter logs using grep
    flutter run \
        --verbose \
        --debug \
        --dart-define=FLUTTER_LOG_LEVEL=debug \
        --enable-dart-profiling \
        "$@" 2>&1 | grep -i "VimbisoPay/$TAG"
else
    # If no TAG specified, show all logs
    flutter run \
        --verbose \
        --debug \
        --dart-define=FLUTTER_LOG_LEVEL=debug \
        --enable-dart-profiling \
        "$@"
fi
