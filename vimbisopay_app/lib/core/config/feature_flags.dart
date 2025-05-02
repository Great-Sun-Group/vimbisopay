/// Configuration for feature flags in the VimbisoPay app.
///
/// This file defines constants for all feature flags and their default values.
/// Feature flags are used to control the visibility and availability of features
/// in the app, allowing for gradual rollout and A/B testing.
class FeatureFlags {
  /// Private constructor to prevent instantiation
  FeatureFlags._();

  /// Feature flag key for the marketplace feature.
  ///
  /// When enabled, users can access the marketplace functionality including:
  /// - Vendor profiles
  /// - Product listings
  /// - Invoicing
  ///
  /// Default value: false (disabled)
  static const String enableMarketplace = 'enable_marketplace';

  /// Feature flag key for debug features.
  ///
  /// When enabled, debug-related UI elements will be shown:
  /// - Debug Tools in Settings screen
  /// - Recent Activity in Security Settings screen
  ///
  /// Default value: false (disabled in release builds)
  static const String enableDebugFeatures = 'enable_debug_features';

  /// Default values for feature flags.
  ///
  /// These values are used as fallbacks when remote config is not available
  /// or when the app is offline.
  static final Map<String, dynamic> defaults = {
    enableMarketplace: false,  // Changed to match Firebase Console setting
    enableDebugFeatures: true,  // Disabled by default for release builds
  };
}
