import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimbisopay_app/core/config/feature_flags.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';

/// Service for managing feature flags in the VimbisoPay app.
///
/// This service uses Firebase Remote Config to control feature flags,
/// allowing for remote control of features without app updates.
/// It also supports local overrides for debugging purposes.
class FeatureFlagService {
  final FirebaseRemoteConfig _remoteConfig;
  final SharedPreferences _prefs;
  
  // Keys for local overrides in SharedPreferences
  static const String _marketplaceOverrideKey = 'debug_override_marketplace';
  static const String _debugFeaturesOverrideKey = 'debug_override_debug_features';
  
  /// Creates a new instance of [FeatureFlagService].
  ///
  /// Requires an instance of [FirebaseRemoteConfig] and [SharedPreferences].
  FeatureFlagService(this._remoteConfig, this._prefs);
  
  /// Initializes the feature flag service.
  ///
  /// Sets default values and configures Remote Config settings.
  /// Returns true if initialization was successful, false otherwise.
  Future<bool> initialize() async {
    try {
      // Set default values
      await _remoteConfig.setDefaults(FeatureFlags.defaults);
      
      // Set fetch timeout and minimum fetch interval
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1), // Changed back to 1 hour to improve startup time
      ));
      
      Logger.data('Remote Config settings configured with 1 hour minimum fetch interval');
      
      // Fetch and activate
      return await fetchAndActivate();
    } catch (e) {
      Logger.error('Error initializing feature flag service', e);
      return false;
    }
  }
  
  /// Fetches the latest parameter values from the Firebase Remote Config backend
  /// and activates them.
  ///
  /// Returns true if fetch and activate was successful, false otherwise.
  Future<bool> fetchAndActivate() async {
    try {
      Logger.data('Starting remote config fetch...');
      await _remoteConfig.fetch();
      Logger.data('Remote config fetch completed');
      
      Logger.data('Starting remote config activation...');
      final updated = await _remoteConfig.activate();
      Logger.data('Remote config updated: $updated');
      
      // Log all config values for debugging
      Logger.data('Current remote config values:');
      Logger.data('- enable_marketplace: ${_remoteConfig.getBool(FeatureFlags.enableMarketplace)}');
      Logger.data('- enable_debug_features: ${_remoteConfig.getBool(FeatureFlags.enableDebugFeatures)}');
      
      return true;
    } catch (e, stackTrace) {
      Logger.error('Error fetching remote config: $e');
      Logger.error('Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Forces a refresh of the remote config values.
  ///
  /// This method is useful for debugging and testing.
  /// It bypasses the minimum fetch interval and forces a new fetch.
  Future<bool> forceRefresh() async {
    try {
      Logger.data('Forcing remote config refresh...');
      
      // Set minimum fetch interval to zero to ensure we can fetch immediately
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: Duration.zero,
      ));
      
      // Fetch and activate
      return await fetchAndActivate();
    } catch (e) {
      Logger.error('Error forcing remote config refresh', e);
      return false;
    }
  }
  
  /// Checks if the marketplace feature is enabled.
  ///
  /// Returns true if the marketplace feature is enabled, false otherwise.
  /// If a local override is set, it takes precedence over the remote config value.
  bool isMarketplaceEnabled() {
    // Check if there's a local override
    if (_prefs.containsKey(_marketplaceOverrideKey)) {
      final localOverride = _prefs.getBool(_marketplaceOverrideKey);
      Logger.data('Using local override for marketplace feature: $localOverride');
      return localOverride ?? _remoteConfig.getBool(FeatureFlags.enableMarketplace);
    }
    
    // Otherwise use the remote config value
    return _remoteConfig.getBool(FeatureFlags.enableMarketplace);
  }
  
  /// Sets a local override for the marketplace feature flag.
  ///
  /// This is useful for debugging and testing purposes.
  /// Returns true if the override was set successfully, false otherwise.
  Future<bool> setMarketplaceOverride(bool enabled) async {
    try {
      Logger.data('Setting local override for marketplace feature: $enabled');
      final result = await _prefs.setBool(_marketplaceOverrideKey, enabled);
      return result;
    } catch (e) {
      Logger.error('Error setting marketplace override', e);
      return false;
    }
  }
  
  /// Clears the local override for the marketplace feature flag.
  ///
  /// Returns true if the override was cleared successfully, false otherwise.
  Future<bool> clearMarketplaceOverride() async {
    try {
      Logger.data('Clearing local override for marketplace feature');
      final result = await _prefs.remove(_marketplaceOverrideKey);
      return result;
    } catch (e) {
      Logger.error('Error clearing marketplace override', e);
      return false;
    }
  }
  
  /// Checks if there's a local override for the marketplace feature flag.
  ///
  /// Returns true if there's a local override, false otherwise.
  bool hasMarketplaceOverride() {
    return _prefs.containsKey(_marketplaceOverrideKey);
  }
  
  /// Gets the value of the local override for the marketplace feature flag.
  ///
  /// Returns the value of the override, or null if there's no override.
  bool? getMarketplaceOverrideValue() {
    if (!_prefs.containsKey(_marketplaceOverrideKey)) {
      return null;
    }
    return _prefs.getBool(_marketplaceOverrideKey);
  }
  
  /// Checks if debug features are enabled.
  ///
  /// Returns true if debug features are enabled, false otherwise.
  /// Debug features are always disabled in release builds, regardless of remote config.
  bool isDebugFeaturesEnabled() {
    // For release builds, always return false regardless of remote config or local override
    if (kReleaseMode) {
      return false;
    }
    
    // For debug/profile builds, check if there's a local override
    if (_prefs.containsKey(_debugFeaturesOverrideKey)) {
      final localOverride = _prefs.getBool(_debugFeaturesOverrideKey);
      Logger.data('Using local override for debug features: $localOverride');
      return localOverride ?? _remoteConfig.getBool(FeatureFlags.enableDebugFeatures);
    }
    
    // Otherwise use the remote config value
    return _remoteConfig.getBool(FeatureFlags.enableDebugFeatures);
  }
  
  /// Sets a local override for the debug features flag.
  ///
  /// This is useful for debugging and testing purposes.
  /// Returns true if the override was set successfully, false otherwise.
  Future<bool> setDebugFeaturesOverride(bool enabled) async {
    try {
      Logger.data('Setting local override for debug features: $enabled');
      final result = await _prefs.setBool(_debugFeaturesOverrideKey, enabled);
      return result;
    } catch (e) {
      Logger.error('Error setting debug features override', e);
      return false;
    }
  }
  
  /// Clears the local override for the debug features flag.
  ///
  /// Returns true if the override was cleared successfully, false otherwise.
  Future<bool> clearDebugFeaturesOverride() async {
    try {
      Logger.data('Clearing local override for debug features');
      final result = await _prefs.remove(_debugFeaturesOverrideKey);
      return result;
    } catch (e) {
      Logger.error('Error clearing debug features override', e);
      return false;
    }
  }
  
  /// Checks if there's a local override for the debug features flag.
  ///
  /// Returns true if there's a local override, false otherwise.
  bool hasDebugFeaturesOverride() {
    return _prefs.containsKey(_debugFeaturesOverrideKey);
  }
  
  /// Gets the value of the local override for the debug features flag.
  ///
  /// Returns the value of the override, or null if there's no override.
  bool? getDebugFeaturesOverrideValue() {
    if (!_prefs.containsKey(_debugFeaturesOverrideKey)) {
      return null;
    }
    return _prefs.getBool(_debugFeaturesOverrideKey);
  }
}
