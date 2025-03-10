import 'package:firebase_remote_config/firebase_remote_config.dart';
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
        minimumFetchInterval: Duration.zero, // Changed from hours: 1 to zero for testing
      ));
      
      Logger.data('Remote Config settings configured with zero minimum fetch interval');
      
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
}
