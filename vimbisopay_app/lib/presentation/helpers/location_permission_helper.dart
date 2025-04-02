import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/location_service.dart';

/// A helper class for handling location permission requests and retrieving location data.
class LocationPermissionHelper {
  final LocationService _locationService;
  final BuildContext _context;
  bool _isRequestingLocation = false;

  LocationPermissionHelper(this._locationService, this._context);

  /// Requests location permission from the user.
  ///
  /// This method shows a dialog explaining why we need location permission
  /// and then requests the permission if the user agrees.
  Future<void> requestLocationPermission({
    required Function(bool) onRequestingStateChanged,
    required Function(double, double)? onLocationReceived,
  }) async {
    if (_isRequestingLocation) return;
    
    _isRequestingLocation = true;
    onRequestingStateChanged(_isRequestingLocation);
    
    try {
      Logger.data('[MARKETPLACE] Checking if location services are enabled');
      
      // Check if location services are enabled
      bool servicesEnabled = await _locationService.checkLocationServicesEnabled();
      if (!servicesEnabled) {
        Logger.data('[MARKETPLACE] Location services are disabled');
        _isRequestingLocation = false;
        onRequestingStateChanged(_isRequestingLocation);
        return;
      }
      
      // Check if permission is already granted
      bool hasPermission = await _locationService.checkLocationPermission();
      if (hasPermission) {
        Logger.data('[MARKETPLACE] Location permission already granted');
        // Get current location
        await _getCurrentLocation(onLocationReceived);
        _isRequestingLocation = false;
        onRequestingStateChanged(_isRequestingLocation);
        return;
      }
      
      // Show a dialog explaining why we need location permission
      final shouldRequest = await showDialog<bool>(
        context: _context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Location Permission'),
          content: const Text(
            'To help you find nearby products and services, we need your location. '
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
        Logger.data('[MARKETPLACE] User declined to request location permission');
        _isRequestingLocation = false;
        onRequestingStateChanged(_isRequestingLocation);
        return;
      }
      
      // Request permission
      final permissionGranted = await _locationService.requestLocationPermission();
      Logger.data('[MARKETPLACE] Location permission request result: $permissionGranted');
      
      if (permissionGranted) {
        // Get current location
        await _getCurrentLocation(onLocationReceived);
      }
    } catch (e) {
      Logger.error('[MARKETPLACE] Error requesting location permission', e);
    } finally {
      _isRequestingLocation = false;
      onRequestingStateChanged(_isRequestingLocation);
    }
  }
  
  /// Gets the current location if available.
  Future<void> _getCurrentLocation(Function(double, double)? onLocationReceived) async {
    try {
      Logger.data('[MARKETPLACE] Getting current location');
      
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        Logger.data('[MARKETPLACE] Got location: (${position.latitude}, ${position.longitude})');
        if (onLocationReceived != null) {
          onLocationReceived(position.latitude, position.longitude);
        }
      } else {
        Logger.error('[MARKETPLACE] Failed to get location');
      }
    } catch (e) {
      Logger.error('[MARKETPLACE] Error getting current location', e);
    }
  }
}
