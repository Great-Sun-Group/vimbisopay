#!/bin/bash

set -e

# Function to echo with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if two arguments are provided
if [ $# -ne 2 ]; then
    log "Usage: $0 <from_branch> <to_branch>"
    log "Note: This script will automatically use the remote branches."
    exit 1
fi

from_branch=$1
to_branch=$2

# Set output file path to be in same directory as script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output_file="$script_dir/diff_output.txt"

# Debug: Print the branch names
log "From branch: $from_branch"
log "To branch: $to_branch"

# Fetch the latest changes from the remote repository
log "Fetching latest changes..."
timeout 60s git fetch origin || { log "Fetch timed out after 60 seconds"; exit 1; }
log "Fetch completed."

# Debug: List remote branches
log "Listing remote branches:"
git --no-pager branch -r

# Get the diff for all files
log "Getting diff for all changed files..."
diff_output=$(git --no-pager diff --no-color --ignore-all-space --ignore-blank-lines "origin/$to_branch".."origin/$from_branch")

# Check if there are any differences
if [ -z "$diff_output" ]; then
    log "No differences found between $from_branch and $to_branch."
    summary="No changes detected between $from_branch and $to_branch branches."
else
    log "Differences found. Writing to $output_file"

    # Get the list of changed files
    changed_files=$(git diff --name-only "origin/$to_branch".."origin/$from_branch")

    summary="Changed files:
$changed_files

Diff:
\`\`\`diff
$diff_output
\`\`\`"

    # Write the summary to the output file
    echo "$summary" > "$output_file"
    log "Diff has been written to $output_file"
fi

# Output a shorter summary to stdout
echo "--- BEGIN SUMMARY ---"
echo "Changes detected between $from_branch and $to_branch branches."
echo ""
echo "Changed files:"
echo "$changed_files"
echo ""
echo "Full diff has been written to: $output_file"
echo "--- END SUMMARY ---"