import 'package:flutter/foundation.dart';

/// Abstract interface for storage operations.
///
/// This interface defines the common methods for both SharedPreferences and
/// flutter_secure_storage, allowing for a smooth migration between the two.
abstract class StorageService {
  /// Initializes the storage service.
  ///
  /// This method should be called before using the storage service.
  Future<void> initialize();

  /// Reads a string value from storage.
  ///
  /// Returns null if the key doesn't exist.
  Future<String?> getString(String key);

  /// Writes a string value to storage.
  ///
  /// Returns true if the operation was successful.
  Future<bool> setString(String key, String value);

  /// Reads a boolean value from storage.
  ///
  /// Returns null if the key doesn't exist.
  Future<bool?> getBool(String key);

  /// Writes a boolean value to storage.
  ///
  /// Returns true if the operation was successful.
  Future<bool> setBool(String key, bool value);

  /// Reads an integer value from storage.
  ///
  /// Returns null if the key doesn't exist.
  Future<int?> getInt(String key);

  /// Writes an integer value to storage.
  ///
  /// Returns true if the operation was successful.
  Future<bool> setInt(String key, int value);

  /// Reads a double value from storage.
  ///
  /// Returns null if the key doesn't exist.
  Future<double?> getDouble(String key);

  /// Writes a double value to storage.
  ///
  /// Returns true if the operation was successful.
  Future<bool> setDouble(String key, double value);

  /// Reads a string list from storage.
  ///
  /// Returns null if the key doesn't exist.
  Future<List<String>?> getStringList(String key);

  /// Writes a string list to storage.
  ///
  /// Returns true if the operation was successful.
  Future<bool> setStringList(String key, List<String> value);

  /// Checks if the storage contains a key.
  ///
  /// Returns true if the key exists.
  Future<bool> containsKey(String key);

  /// Removes a key from storage.
  ///
  /// Returns true if the operation was successful.
  Future<bool> remove(String key);

  /// Clears all keys from storage.
  ///
  /// Returns true if the operation was successful.
  Future<bool> clear();

  /// Gets all keys in storage.
  ///
  /// Returns a set of all keys.
  Future<Set<String>> getKeys();

  /// Reloads the storage from disk.
  ///
  /// This is useful when the storage might have been modified outside of this instance.
  Future<void> reload();
}
