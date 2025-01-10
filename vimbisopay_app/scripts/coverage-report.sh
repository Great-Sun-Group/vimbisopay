#!/bin/bash

# Run flutter tests with coverage
flutter test --coverage

# Check if lcov is installed
if ! command -v lcov &> /dev/null; then
    echo "lcov is not installed. Installing via brew..."
    brew install lcov
fi

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open the report in default browser
open coverage/html/index.html

echo "Coverage report generated and opened in browser"
