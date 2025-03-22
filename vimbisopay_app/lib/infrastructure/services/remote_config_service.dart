import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

/// Service for managing remote configuration in the VimbisoPay app.
///
/// This service fetches configuration from the server and provides methods
/// for accessing configuration values.
class RemoteConfigService {
  final http.Client _httpClient;
  final SharedPreferences _prefs;
  final String _baseUrl;
  
  // Keys for SharedPreferences
  static const String _configCacheKey = 'remote_config_cache';
  static const String _configTimestampKey = 'remote_config_timestamp';
  
  // Default TTL for cached config (1 hour)
  static const int _defaultTtlSeconds = 3600;
  
  // In-memory cache of the config
  Map<String, dynamic>? _cachedConfig;
  
  /// Creates a new instance of [RemoteConfigService].
  ///
  /// Requires an instance of [http.Client] and [SharedPreferences].
  RemoteConfigService(this._httpClient, this._prefs, this._baseUrl);
  
  /// Initializes the remote config service.
  ///
  /// Loads the cached config from SharedPreferences.
  /// Returns true if initialization was successful, false otherwise.
  Future<bool> initialize() async {
    try {
      // Load cached config from SharedPreferences
      final cachedConfigJson = _prefs.getString(_configCacheKey);
      if (cachedConfigJson != null) {
        _cachedConfig = jsonDecode(cachedConfigJson) as Map<String, dynamic>;
        Logger.data('Loaded cached remote config');
      }
      
      return true;
    } catch (e) {
      Logger.error('Error initializing remote config service', e);
      return false;
    }
  }
  
  /// Fetches the latest configuration from the server.
  ///
  /// Returns true if fetch was successful, false otherwise.
  Future<bool> fetchConfig() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final packageName = packageInfo.packageName;
      
      // Get device info
      final deviceInfo = await _getDeviceInfo();
      
      // Get user info from database
      final user = await ServiceLocator.databaseHelper.getUser();
      final userId = user?.memberId;
      
      // Get last config timestamp
      final lastConfigTimestamp = _prefs.getInt(_configTimestampKey);
      
      // Build request body
      final requestBody = {
        'app_id': packageName,
        'app_version': currentVersion,
        'device_info': deviceInfo,
        if (userId != null) 'user_id': userId,
        if (lastConfigTimestamp != null) 'last_config_timestamp': lastConfigTimestamp,
      };
      
      // Make API request
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/api/v1/app/config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Cache the config
        _cachedConfig = data;
        await _prefs.setString(_configCacheKey, jsonEncode(data));
        
        // Store the timestamp
        final timestamp = data['config_timestamp'] as int?;
        if (timestamp != null) {
          await _prefs.setInt(_configTimestampKey, timestamp);
        }
        
        Logger.data('Successfully fetched remote config from server');
        return true;
      } else {
        Logger.error('Error fetching remote config: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      Logger.error('Error fetching remote config', e);
      return false;
    }
  }
  
  /// Gets a feature flag value from the remote config.
  ///
  /// Returns the value of the feature flag, or the default value if not found.
  bool getFeatureFlag(String key, {bool defaultValue = false}) {
    if (_cachedConfig == null) {
      return defaultValue;
    }
    
    final featureFlags = _cachedConfig!['feature_flags'] as Map<String, dynamic>?;
    if (featureFlags == null) {
      return defaultValue;
    }
    
    return featureFlags[key] as bool? ?? defaultValue;
  }
  
  /// Gets a remote variable value from the remote config.
  ///
  /// Returns the value of the remote variable, or the default value if not found.
  T getRemoteVariable<T>(String key, T defaultValue) {
    if (_cachedConfig == null) {
      return defaultValue;
    }
    
    final remoteVariables = _cachedConfig!['remote_variables'] as Map<String, dynamic>?;
    if (remoteVariables == null) {
      return defaultValue;
    }
    
    final value = remoteVariables[key];
    if (value == null) {
      return defaultValue;
    }
    
    // Try to convert the value to the requested type
    if (T == String) {
      return value.toString() as T;
    } else if (T == int) {
      return (value is int ? value : int.tryParse(value.toString()) ?? defaultValue) as T;
    } else if (T == double) {
      return (value is double ? value : double.tryParse(value.toString()) ?? defaultValue) as T;
    } else if (T == bool) {
      return (value is bool ? value : value.toString().toLowerCase() == 'true') as T;
    } else if (T == List<String>) {
      if (value is List) {
        return value.map((e) => e.toString()).toList() as T;
      }
      return defaultValue;
    } else if (T == Map<String, dynamic>) {
      return (value is Map ? value : defaultValue) as T;
    }
    
    return defaultValue;
  }
  
  /// Gets a user-specific configuration value from the remote config.
  ///
  /// Returns the value of the user-specific configuration, or the default value if not found.
  T getUserConfig<T>(String key, T defaultValue) {
    if (_cachedConfig == null) {
      return defaultValue;
    }
    
    final userConfig = _cachedConfig!['user_specific_config'] as Map<String, dynamic>?;
    if (userConfig == null) {
      return defaultValue;
    }
    
    final value = userConfig[key];
    if (value == null) {
      return defaultValue;
    }
    
    // Try to convert the value to the requested type
    if (T == String) {
      return value.toString() as T;
    } else if (T == int) {
      return (value is int ? value : int.tryParse(value.toString()) ?? defaultValue) as T;
    } else if (T == double) {
      return (value is double ? value : double.tryParse(value.toString()) ?? defaultValue) as T;
    } else if (T == bool) {
      return (value is bool ? value : value.toString().toLowerCase() == 'true') as T;
    }
    
    return defaultValue;
  }
  
  /// Gets an A/B test variant assignment from the remote config.
  ///
  /// Returns the variant name, or the default variant if not found.
  String getAbTestVariant(String testName, String defaultVariant) {
    if (_cachedConfig == null) {
      return defaultVariant;
    }
    
    final abTests = _cachedConfig!['ab_test_assignments'] as Map<String, dynamic>?;
    if (abTests == null) {
      return defaultVariant;
    }
    
    return abTests[testName] as String? ?? defaultVariant;
  }
  
  /// Checks if the cached config is still valid.
  ///
  /// Returns true if the cached config is still valid, false otherwise.
  bool isCacheValid() {
    if (_cachedConfig == null) {
      return false;
    }
    
    final timestamp = _prefs.getInt(_configTimestampKey);
    if (timestamp == null) {
      return false;
    }
    
    final ttl = _cachedConfig!['config_ttl_seconds'] as int? ?? _defaultTtlSeconds;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    return now - timestamp < ttl * 1000;
  }
  
  /// Gets device information for the config request.
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      return {
        'android_version': androidInfo.version.release,
        'device_model': androidInfo.model,
        'screen_size': '${androidInfo.displayMetrics.widthPx.toInt()}x${androidInfo.displayMetrics.heightPx.toInt()}',
      };
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      return {
        'ios_version': iosInfo.systemVersion,
        'device_model': iosInfo.model,
      };
    }
    
    return {};
  }
}
