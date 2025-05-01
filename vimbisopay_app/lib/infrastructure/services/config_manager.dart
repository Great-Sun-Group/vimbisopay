import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/app_update_service.dart';
import 'package:vimbisopay_app/infrastructure/services/feature_flag_service.dart';
import 'package:vimbisopay_app/infrastructure/services/remote_config_service.dart';

/// Manager for coordinating between remote config and app updates.
///
/// This class provides a unified interface for the app to access configuration
/// and update functionality.
class ConfigManager {
  final FeatureFlagService _featureFlagService;
  final RemoteConfigService _remoteConfigService;
  final AppUpdateService _appUpdateService;
  
  /// Creates a new instance of [ConfigManager].
  ///
  /// Requires instances of [FeatureFlagService], [RemoteConfigService], and [AppUpdateService].
  ConfigManager(
    this._featureFlagService,
    this._remoteConfigService,
    this._appUpdateService,
  );
  
  /// Initializes the config manager.
  ///
  /// This initializes all the underlying services.
  /// Returns true if initialization was successful, false otherwise.
  Future<bool> initialize() async {
    try {
      // Initialize feature flag service
      final featureFlagsInitialized = await _featureFlagService.initialize();
      if (!featureFlagsInitialized) {
        Logger.error('Failed to initialize feature flag service');
      }
      
      // Initialize remote config service
      final remoteConfigInitialized = await _remoteConfigService.initialize();
      if (!remoteConfigInitialized) {
        Logger.error('Failed to initialize remote config service');
      }
      
      // Fetch remote config if cache is invalid
      if (!_remoteConfigService.isCacheValid()) {
        await _remoteConfigService.fetchConfig();
      }
      
      return featureFlagsInitialized && remoteConfigInitialized;
    } catch (e) {
      Logger.error('Error initializing config manager', e);
      return false;
    }
  }
  
  /// Refreshes all configuration.
  ///
  /// This fetches the latest configuration from both Firebase and the server.
  /// Returns true if refresh was successful, false otherwise.
  Future<bool> refreshAll() async {
    try {
      // Refresh Firebase Remote Config
      final firebaseRefreshed = await _featureFlagService.forceRefresh();
      
      // Refresh server config
      final serverRefreshed = await _remoteConfigService.fetchConfig();
      
      return firebaseRefreshed && serverRefreshed;
    } catch (e) {
      Logger.error('Error refreshing configuration', e);
      return false;
    }
  }
  
  /// Checks if a feature flag is enabled.
  ///
  /// This checks both the server config and Firebase Remote Config.
  /// Server config takes precedence over Firebase Remote Config.
  bool isFeatureEnabled(String key, {bool defaultValue = false}) {
    // Check server config first
    final serverValue = _remoteConfigService.getFeatureFlag(key, defaultValue: defaultValue);
    
    // If the key is 'enable_marketplace', use the feature flag service
    if (key == 'enable_marketplace') {
      return _featureFlagService.isMarketplaceEnabled();
    }
    
    return serverValue;
  }
  
  /// Gets a remote variable value.
  ///
  /// This gets the value from the server config.
  T getRemoteVariable<T>(String key, T defaultValue) {
    return _remoteConfigService.getRemoteVariable(key, defaultValue);
  }
  
  /// Gets a user-specific configuration value.
  ///
  /// This gets the value from the server config.
  T getUserConfig<T>(String key, T defaultValue) {
    return _remoteConfigService.getUserConfig(key, defaultValue);
  }
  
  /// Gets an A/B test variant assignment.
  ///
  /// This gets the value from the server config.
  String getAbTestVariant(String testName, String defaultVariant) {
    return _remoteConfigService.getAbTestVariant(testName, defaultVariant);
  }
  
  /// Checks for app updates.
  ///
  /// Returns a [Map] containing information about the available update,
  /// or null if no update is available.
  Future<Map<String, dynamic>?> checkForUpdate() {
    return _appUpdateService.checkForUpdate();
  }
  
  /// Shows an update dialog to the user.
  ///
  /// Returns true if the user chooses to update, false otherwise.
  Future<bool> showUpdateDialog(
    BuildContext context,
    Map<String, dynamic> updateInfo,
  ) {
    return _appUpdateService.showUpdateDialog(context, updateInfo);
  }
  
  /// Downloads and installs an update.
  ///
  /// If integrity information is available in the update info, it will be used
  /// to verify the downloaded file before installation.
  ///
  /// Returns true if the download and installation was successful, false otherwise.
  Future<bool> downloadAndInstallUpdate(String url, {Map<String, dynamic>? updateInfo}) {
    // Extract integrity information if available
    Map<String, dynamic>? integrity;
    if (updateInfo != null && updateInfo.containsKey('integrity')) {
      integrity = updateInfo['integrity'] as Map<String, dynamic>;
      Logger.data('Integrity information found: ${jsonEncode(integrity)}');
    }
    
    return _appUpdateService.downloadAndInstallUpdate(url, integrity: integrity);
  }
  
  /// Defers an update until later.
  Future<void> deferUpdate(String version) {
    return _appUpdateService.deferUpdate(version);
  }
  
  /// Clears the deferred status of an update.
  Future<void> clearDeferredUpdateStatus() {
    return _appUpdateService.clearDeferredStatus();
  }
  
  /// Retries the installation of a previously downloaded update.
  ///
  /// This is useful when the user has been redirected to enable "Allow from this source"
  /// in the settings and wants to continue the installation process.
  ///
  /// Returns true if the retry was successful, false otherwise.
  Future<bool> retryInstallation() {
    return _appUpdateService.retryInstallation();
  }
}
