# Remote Config and App Updates Implementation

This document provides an overview of the remote configuration and app update features implemented in the VimbisoPay app.

## Overview

The implementation consists of several components:

1. **Remote Config Service**: Fetches configuration from the server and provides methods for accessing configuration values.
2. **App Update Service**: Checks for app updates and handles the update process.
3. **Config Manager**: Coordinates between the Remote Config Service and App Update Service.
4. **Debug Screen**: Provides tools for testing and debugging the remote config and app update features.

## Server API

The server API is documented in [REMOTE_CONFIG_AND_UPDATES_API.md](REMOTE_CONFIG_AND_UPDATES_API.md). This document provides detailed specifications for the server-side API endpoints required to support remote configuration and app updates.

## Client Implementation

### Remote Config Service

The `RemoteConfigService` class is responsible for fetching configuration from the server and providing methods for accessing configuration values. It supports:

- Feature flags
- Remote variables
- User-specific configuration
- A/B test variant assignments

```dart
// Example usage
final remoteConfigService = ServiceLocator.remoteConfigService;
final isFeatureEnabled = remoteConfigService.getFeatureFlag('feature_key');
final apiEndpoint = remoteConfigService.getRemoteVariable<String>('api_endpoint', 'https://default-api.example.com');
final maxTransactionAmount = remoteConfigService.getUserConfig<int>('max_transaction_amount', 1000);
final abTestVariant = remoteConfigService.getAbTestVariant('new_onboarding_flow', 'control');
```

### App Update Service

The `AppUpdateService` class is responsible for checking for app updates and handling the update process. It supports:

- Checking for updates
- Downloading and installing updates
- Showing update dialogs
- Deferring updates

```dart
// Example usage
final appUpdateService = ServiceLocator.appUpdateService;
final updateInfo = await appUpdateService.checkForUpdate();
if (updateInfo != null) {
  final shouldUpdate = await appUpdateService.showUpdateDialog(context, updateInfo);
  if (shouldUpdate) {
    await appUpdateService.downloadAndInstallUpdate(updateInfo['update_url']);
  } else {
    await appUpdateService.deferUpdate(updateInfo['latest_version']);
  }
}
```

### Config Manager

The `ConfigManager` class coordinates between the Remote Config Service and App Update Service, providing a unified interface for the app to access configuration and update functionality.

```dart
// Example usage
final configManager = ServiceLocator.configManager;
final isFeatureEnabled = configManager.isFeatureEnabled('feature_key');
final updateInfo = await configManager.checkForUpdate();
```

## Integration with Firebase Remote Config

The implementation integrates with Firebase Remote Config to provide a fallback mechanism for feature flags. The `FeatureFlagService` class is responsible for managing feature flags using Firebase Remote Config.

## Debug Tools

The Debug Screen provides tools for testing and debugging the remote config and app update features:

1. **Feature Flags Tab**: Allows you to view and modify feature flags.
2. **App Updates Tab**: Allows you to check for updates, view update information, and test the update process.
3. **Notifications Tab**: Allows you to test push notifications.

## How to Use

### Initialization

The remote config and app update services are initialized during app startup in the `main.dart` file:

```dart
// Initialize config services
print('Initializing config services...');
final configManager = await ServiceLocator.initializeConfigServices();

Logger.data('ConfigManager initialized successfully');
Logger.data('Marketplace feature enabled: ${configManager.isFeatureEnabled('enable_marketplace')}');

// Check for app updates
print('Checking for app updates...');
final updateInfo = await configManager.checkForUpdate();
if (updateInfo != null) {
  Logger.data('Update available: ${updateInfo['latest_version']}');
  Logger.data('Update required: ${updateInfo['update_required']}');
} else {
  Logger.data('No updates available');
}
```

### Checking for Updates

To check for updates and show an update dialog:

```dart
final updateInfo = await ServiceLocator.configManager.checkForUpdate();
if (updateInfo != null) {
  final shouldUpdate = await ServiceLocator.configManager.showUpdateDialog(context, updateInfo);
  if (shouldUpdate) {
    await ServiceLocator.configManager.downloadAndInstallUpdate(updateInfo['update_url']);
  }
}
```

### Accessing Configuration

To access configuration values:

```dart
final isFeatureEnabled = ServiceLocator.configManager.isFeatureEnabled('feature_key');
final apiEndpoint = ServiceLocator.configManager.getRemoteVariable<String>('api_endpoint', 'https://default-api.example.com');
```

## Testing

You can test the remote config and app update features using the Debug Screen:

1. Navigate to the Debug Screen by going to `/debug` in the app.
2. Use the Feature Flags tab to test feature flags.
3. Use the App Updates tab to test app updates.

## Troubleshooting

If you encounter issues with the remote config or app update features:

1. Check the logs for error messages.
2. Verify that the server API is implemented correctly.
3. Use the Debug Screen to test the features.
4. Ensure that the app has the necessary permissions to download and install updates.
