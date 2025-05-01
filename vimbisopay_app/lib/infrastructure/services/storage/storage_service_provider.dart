import 'package:vimbisopay_app/infrastructure/services/storage/secure_storage_service.dart';
import 'package:vimbisopay_app/infrastructure/services/storage/storage_service.dart';

/// Provider for storage services.
///
/// This class is responsible for creating and providing storage service instances.
class StorageServiceProvider {
  static StorageService? _storageService;

  /// Gets the storage service instance.
  ///
  /// If the service hasn't been initialized yet, it will be created.
  static StorageService get storageService {
    if (_storageService == null) {
      throw Exception('StorageService not initialized. Call initialize() first.');
    }
    return _storageService!;
  }

  /// Initializes the storage service.
  ///
  /// This method should be called during app initialization before using the storage service.
  static Future<StorageService> initialize() async {
    if (_storageService != null) {
      return _storageService!;
    }

    // Create and initialize the secure storage service
    final secureStorage = SecureStorageService();
    await secureStorage.initialize();
    _storageService = secureStorage;
    
    return _storageService!;
  }
}
