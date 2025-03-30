import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/location_service.dart';
import 'package:flutter/material.dart';

/// Service for handling store status operations.
///
/// This service provides methods for checking location services,
/// requesting location permissions, and updating store status.
class StoreStatusService {
  final MarketplaceRepository _marketplaceRepository;
  final DatabaseHelper _databaseHelper;
  final LocationService _locationService;

  /// Creates a new [StoreStatusService] instance.
  ///
  /// Requires a marketplace repository for API communication,
  /// a database helper for accessing user data, and a location service
  /// for getting the user's location.
  StoreStatusService({
    required MarketplaceRepository marketplaceRepository,
    required DatabaseHelper databaseHelper,
    required LocationService locationService,
  })  : _marketplaceRepository = marketplaceRepository,
        _databaseHelper = databaseHelper,
        _locationService = locationService;

  /// Checks if location services are enabled and prompts the user to enable them if not.
  ///
  /// Returns true if location services are enabled, false otherwise.
  Future<bool> checkLocationServicesEnabled(BuildContext context) async {
    Logger.data('[STORE_STATUS] Checking if location services are enabled');
    
    // Check if location services are enabled
    bool servicesEnabled = await _locationService.checkLocationServicesEnabled();
    if (servicesEnabled) {
      Logger.data('[STORE_STATUS] Location services are enabled');
      return true;
    }
    
    // Show a dialog explaining why we need location services enabled
    if (context.mounted) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Your device\'s location services are turned off. To mark your store as open, '
            'we need your location to help customers find you.\n\n'
            'Would you like to open settings to enable location services?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ) ?? false;
      
      if (shouldOpenSettings) {
        Logger.data('[STORE_STATUS] Opening location settings');
        await _locationService.openLocationSettings();
        
        // Give the user some time to change settings
        await Future.delayed(const Duration(seconds: 2));
        
        // Check again if location services are now enabled
        servicesEnabled = await _locationService.checkLocationServicesEnabled();
        if (servicesEnabled) {
          Logger.data('[STORE_STATUS] Location services are now enabled');
          return true;
        } else {
          Logger.data('[STORE_STATUS] Location services are still disabled');
          return false;
        }
      } else {
        Logger.data('[STORE_STATUS] User declined to open location settings');
        return false;
      }
    }
    
    return false;
  }

  /// Requests location permission with a clear explanation to the user.
  ///
  /// Returns true if permission is granted, false otherwise.
  Future<bool> requestLocationPermission(BuildContext context) async {
    Logger.data('[STORE_STATUS] Requesting location permission');
    
    // First check if location services are enabled
    bool servicesEnabled = await checkLocationServicesEnabled(context);
    if (!servicesEnabled) {
      Logger.data('[STORE_STATUS] Location services are disabled, cannot proceed with permission request');
      return false;
    }
    
    // Check if permission is already granted
    bool hasPermission = await _locationService.checkLocationPermission();
    if (hasPermission) {
      Logger.data('[STORE_STATUS] Location permission already granted');
      return true;
    }
    
    // Show a dialog explaining why we need location permission
    if (context.mounted) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Location Permission'),
          content: const Text(
            'To mark your store as open, we need your location to help customers find you. '
            'Would you like to grant location permission?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      ) ?? false;
      
      if (!shouldRequest) {
        Logger.data('[STORE_STATUS] User declined to request location permission');
        return false;
      }
    }
    
    // Request permission
    final permissionGranted = await _locationService.requestLocationPermission();
    Logger.data('[STORE_STATUS] Location permission request result: $permissionGranted');
    
    return permissionGranted;
  }

  /// Gets the current location if available.
  ///
  /// Returns a tuple of latitude and longitude if successful, null otherwise.
  Future<(double, double)?> getCurrentLocation() async {
    Logger.data('[STORE_STATUS] Getting current location');
    
    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      Logger.data('[STORE_STATUS] Got location: (${position.latitude}, ${position.longitude})');
      return (position.latitude, position.longitude);
    } else {
      Logger.error('[STORE_STATUS] Failed to get location');
      return null;
    }
  }

  /// Finds the personal account ID from the user's dashboard.
  ///
  /// Returns the account ID if found, null otherwise.
  Future<String?> getPersonalAccountId() async {
    Logger.data('[STORE_STATUS] Getting personal account ID');
    
    final user = await _databaseHelper.getUser();
    if (user == null) {
      Logger.error('[STORE_STATUS] User not found in database');
      return null;
    }
    
    // Check if user has a dashboard with accounts
    if (user.dashboard == null) {
      Logger.error('[STORE_STATUS] User dashboard is null');
      return null;
    }
    
    // Try to find an account with accountType PERSONAL
    for (final account in user.dashboard!.accounts) {
      if (account.accountType == 'PERSONAL') {
        Logger.data('[STORE_STATUS] Found PERSONAL account: ${account.accountID} (${account.accountName})');
        return account.accountID;
      }
    }
    
    Logger.error('[STORE_STATUS] No PERSONAL account found');
    return null;
  }

  /// Updates the store status and location.
  ///
  /// Returns a tuple of (success, error message) where success is true if the
  /// operation was successful, and error message is null if there was no error.
  Future<(bool, String?)> updateStoreStatus({
    required bool storeOpen,
    double? latitude,
    double? longitude,
  }) async {
    Logger.data('[STORE_STATUS] Updating store status to: ${storeOpen ? 'Open' : 'Closed'}');
    Logger.data('[STORE_STATUS] Location: ${latitude != null && longitude != null ? "($latitude, $longitude)" : "Not provided"}');
    
    // Get the personal account ID
    final accountId = await getPersonalAccountId();
    if (accountId == null) {
      const errorMessage = 'No personal account found for store status update';
      Logger.error('[STORE_STATUS] $errorMessage');
      return (false, errorMessage);
    }
    
    // Update store status
    final result = await _marketplaceRepository.updateStoreStatus(
      accountId: accountId,
      storeOpen: storeOpen,
      latitude: latitude,
      longitude: longitude,
    );
    
    return result.fold(
      (failure) {
        Logger.error('[STORE_STATUS] Failed to update store status: ${failure.message}');
        return (false, failure.message);
      },
      (success) {
        Logger.data('[STORE_STATUS] Store status updated successfully');
        return (true, null);
      },
    );
  }
}
