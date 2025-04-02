import 'package:geolocator/geolocator.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:flutter/services.dart';

/// Service for handling location-related operations.
class LocationService {
  /// Requests location permission and gets the current position.
  ///
  /// Returns the current position if successful, or null if an error occurs
  /// or permission is denied.
  Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Logger.error('[LOCATION] Location services are disabled');
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Logger.error('[LOCATION] Location permission denied');
          return null;
        }
      }

      // Handle permanently denied permission
      if (permission == LocationPermission.deniedForever) {
        Logger.error('[LOCATION] Location permission permanently denied');
        return null;
      }

      // Get current position
      Logger.data('[LOCATION] Getting current position');
      final position = await Geolocator.getCurrentPosition();
      Logger.data('[LOCATION] Position obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      Logger.error('[LOCATION] Error getting current position', e);
      return null;
    }
  }

  /// Checks if location services are enabled at the device level.
  ///
  /// Returns true if location services are enabled, false otherwise.
  Future<bool> checkLocationServicesEnabled() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Logger.error('[LOCATION] Location services are disabled');
      } else {
        Logger.data('[LOCATION] Location services are enabled');
      }
      return serviceEnabled;
    } catch (e) {
      Logger.error('[LOCATION] Error checking location services', e);
      return false;
    }
  }

  /// Opens the device location settings page.
  ///
  /// This allows users to enable location services directly from the app.
  Future<void> openLocationSettings() async {
    try {
      Logger.data('[LOCATION] Opening location settings');
      await Geolocator.openLocationSettings();
    } catch (e) {
      Logger.error('[LOCATION] Error opening location settings', e);
      // If the platform-specific implementation fails, we can't do much
      // but we should not crash the app
    }
  }

  /// Checks if location permission is granted.
  ///
  /// Returns true if permission is granted, false otherwise.
  Future<bool> checkLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await checkLocationServicesEnabled();
      if (!serviceEnabled) {
        return false;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      Logger.error('[LOCATION] Error checking location permission', e);
      return false;
    }
  }

  /// Requests location permission.
  ///
  /// Returns true if permission is granted, false otherwise.
  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      Logger.error('[LOCATION] Error requesting location permission', e);
      return false;
    }
  }
}
