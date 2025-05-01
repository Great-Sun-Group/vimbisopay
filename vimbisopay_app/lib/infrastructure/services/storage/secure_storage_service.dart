import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/storage/storage_service.dart';

/// Implementation of [StorageService] using flutter_secure_storage.
///
/// This class provides a secure storage implementation that encrypts data on disk.
/// It implements the same interface as SharedPreferencesService for easy migration.
class SecureStorageService implements StorageService {
  final FlutterSecureStorage _secureStorage;
  final Map<String, dynamic> _cache = {};
  bool _initialized = false;

  /// Creates a new instance of [SecureStorageService].
  ///
  /// By default, it uses the standard secure storage options.
  SecureStorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Load all values into cache for faster access
      final allValues = await _secureStorage.readAll();
      _cache.addAll(allValues);
      _initialized = true;
      Logger.data('SecureStorageService initialized successfully');
    } catch (e) {
      Logger.error('Error initializing SecureStorageService', e);
      rethrow;
    }
  }

  /// Ensures that the service is initialized before use.
  void _ensureInitialized() {
    if (!_initialized) {
      throw Exception('SecureStorageService not initialized. Call initialize() first.');
    }
  }

  @override
  Future<String?> getString(String key) async {
    _ensureInitialized();
    // Try cache first for performance
    if (_cache.containsKey(key)) {
      return _cache[key] as String?;
    }
    // Fall back to storage
    return await _secureStorage.read(key: key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    _ensureInitialized();
    try {
      await _secureStorage.write(key: key, value: value);
      _cache[key] = value;
      return true;
    } catch (e) {
      Logger.error('Error writing string to secure storage', e);
      return false;
    }
  }

  @override
  Future<bool?> getBool(String key) async {
    _ensureInitialized();
    final value = await getString(key);
    if (value == null) return null;
    return value.toLowerCase() == 'true';
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    return await setString(key, value.toString());
  }

  @override
  Future<int?> getInt(String key) async {
    _ensureInitialized();
    final value = await getString(key);
    if (value == null) return null;
    return int.tryParse(value);
  }

  @override
  Future<bool> setInt(String key, int value) async {
    return await setString(key, value.toString());
  }

  @override
  Future<double?> getDouble(String key) async {
    _ensureInitialized();
    final value = await getString(key);
    if (value == null) return null;
    return double.tryParse(value);
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    return await setString(key, value.toString());
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    _ensureInitialized();
    final value = await getString(key);
    if (value == null) return null;
    try {
      final List<dynamic> decoded = jsonDecode(value);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      Logger.error('Error decoding string list from secure storage', e);
      return null;
    }
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    try {
      final encoded = jsonEncode(value);
      return await setString(key, encoded);
    } catch (e) {
      Logger.error('Error encoding string list for secure storage', e);
      return false;
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    _ensureInitialized();
    // Check cache first for performance
    if (_cache.containsKey(key)) {
      return true;
    }
    // Fall back to storage
    final value = await _secureStorage.read(key: key);
    return value != null;
  }

  @override
  Future<bool> remove(String key) async {
    _ensureInitialized();
    try {
      await _secureStorage.delete(key: key);
      _cache.remove(key);
      return true;
    } catch (e) {
      Logger.error('Error removing key from secure storage', e);
      return false;
    }
  }

  @override
  Future<bool> clear() async {
    _ensureInitialized();
    try {
      await _secureStorage.deleteAll();
      _cache.clear();
      return true;
    } catch (e) {
      Logger.error('Error clearing secure storage', e);
      return false;
    }
  }

  @override
  Future<Set<String>> getKeys() async {
    _ensureInitialized();
    try {
      final allValues = await _secureStorage.readAll();
      return allValues.keys.toSet();
    } catch (e) {
      Logger.error('Error getting keys from secure storage', e);
      return {};
    }
  }

  @override
  Future<void> reload() async {
    _ensureInitialized();
    try {
      final allValues = await _secureStorage.readAll();
      _cache.clear();
      _cache.addAll(allValues);
    } catch (e) {
      Logger.error('Error reloading secure storage', e);
      rethrow;
    }
  }
}
