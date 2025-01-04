#!/bin/bash

# GitHub Configuration Template
# ---------------------------
# 1. Copy this file to github_config.sh
# 2. Replace the placeholder values below with your actual values
# 3. Keep github_config.sh secure and do not commit it (it's in .gitignore)

# To get a GitHub token:
# 1. Go to GitHub.com -> Settings -> Developer settings -> Personal access tokens -> Tokens (classic)
# 2. Click "Generate new token" -> "Generate new token (classic)"
# 3. Give it a name (e.g., "Release Management")
# 4. Select the 'repo' scope (this gives access to create releases)
# 5. Click "Generate token"
# 6. Copy the token and paste it below (keep it secure, it won't be shown again!)

# Your GitHub Personal Access Token
GITHUB_TOKEN="your-token-here"

# Your GitHub repository in format "owner/repo"
GITHUB_REPO="owner/repository-name"

# Note: The actual github_config.sh file should never be committed to version control
# This template file serves as a guide for setting up your local configuration
