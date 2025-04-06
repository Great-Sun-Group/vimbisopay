# Firebase Configuration Setup for Codespaces

This document explains how to set up Firebase configuration for the Vimbisopay app when working in GitHub Codespaces.

## Overview

The app requires a `google-services.json` file for Firebase integration. Since this file contains sensitive information (API keys, project IDs), we use GitHub Secrets to securely store and inject this configuration into Codespaces.

## Setup Instructions

### 1. Create the GitHub Secret

1. Go to your GitHub repository settings
2. Navigate to "Secrets and variables" > "Codespaces"
3. Click "New repository secret"
4. Set the name to `FIREBASE_CONFIG`
5. For the value, copy and paste the entire content of your `google-services.json` file.

6. Click "Add secret"

### 2. How It Works

- The `.devcontainer/devcontainer.json` file has been configured to run a setup script when a Codespace is created
- This script (`vimbisopay_app/scripts/setup-firebase-config.sh`) reads the `FIREBASE_CONFIG` environment variable and creates the `google-services.json` file in the correct location
- The file is automatically added to `.gitignore` to prevent accidental commits

### 3. Verification

When you create a new Codespace, you should see a message in the terminal indicating that the Firebase configuration has been set up. You can verify that the file exists at:

```
vimbisopay_app/android/app/google-services.json
```

## Troubleshooting

If the Firebase configuration is not being set up correctly:

1. Check that the `FIREBASE_CONFIG` secret is properly set in your GitHub repository
2. Look for error messages in the terminal output when the Codespace is created
3. Try running the setup script manually:

```bash
chmod +x vimbisopay_app/scripts/setup-firebase-config.sh
./vimbisopay_app/scripts/setup-firebase-config.sh
```

## Security Considerations

- Never commit the `google-services.json` file directly to the repository
- If you need to update the Firebase configuration, update the GitHub Secret
- The setup script sets appropriate file permissions (600) to restrict access to the file
