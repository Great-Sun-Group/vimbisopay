import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/notification_service.dart';

class SecurityService {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;
  static const String _pinKey = 'user_pin';
  static const String _useBiometricKey = 'use_biometric';
  static const String _lastAuthTimeKey = 'last_auth_time';
  static const int _authValidityDuration = 300; // 5 minutes in seconds

  SecurityService()
      : _storage = const FlutterSecureStorage(),
        _localAuth = LocalAuthentication() {
    Logger.lifecycle('SecurityService initialized');
  }

  Future<String?> getSecurePin() async {
    Logger.data('Attempting to get secure PIN');
    try {
      if (await requiresAuthentication()) {
        Logger.state('Authentication required for PIN access');
        if (await usesBiometric()) {
          Logger.state('Biometric is enabled, attempting biometric auth');
          final (authenticated, error) = await authenticateWithBiometrics();
          if (authenticated) {
            Logger.data('Biometric auth successful, retrieving PIN');
            return _storage.read(key: _pinKey);
          }
          Logger.error('Biometric auth failed', error);
        }
        
        Logger.data('Checking for valid PIN');
        final pin = await _storage.read(key: _pinKey);
        if (pin != null) {
          Logger.data('PIN found');
          return pin;
        }
        
        Logger.error('Authentication failed - no valid PIN found');
        throw Exception('Authentication required');
      }
      Logger.data('No authentication required, retrieving PIN');
      return _storage.read(key: _pinKey);
    } catch (e, stack) {
      Logger.error('Error in getSecurePin', e, stack);
      rethrow;
    }
  }

  Future<bool> isBiometricAvailable() async {
    Logger.data('Checking biometric availability');
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      Logger.data('Device biometric support: $isDeviceSupported');
      if (!isDeviceSupported) {
        return false;
      }

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      Logger.data('Can check biometrics: $canCheckBiometrics');
      if (!canCheckBiometrics) {
        return false;
      }

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      Logger.data('Available biometrics: $availableBiometrics');
      return availableBiometrics.isNotEmpty;
    } on PlatformException catch (e) {
      Logger.error('Platform error checking biometric availability', e);
      return false;
    } catch (e, stack) {
      Logger.error('Unexpected error checking biometric availability', e, stack);
      return false;
    }
  }

  Future<(bool, String?)> authenticateWithBiometrics() async {
    Logger.interaction('Starting biometric authentication');
    try {
      if (await _isRecentlyAuthenticated()) {
        Logger.state('Recent authentication found, skipping biometric');
        return (true, null);
      }

      final isAvailable = await isBiometricAvailable();
      Logger.state('Biometric availability: $isAvailable');
      if (!isAvailable) {
        return (false, 'Biometric authentication is not available on this device');
      }

      Logger.interaction('Prompting biometric authentication');
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

      Logger.state('Biometric authentication result: $authenticated');
      if (authenticated) {
        await _markAuthenticationTime();
      }

      return (authenticated, null);
    } on PlatformException catch (e) {
      String errorMessage;
      
      switch (e.code) {
        case auth_error.notAvailable:
          errorMessage = 'Biometric authentication is not available';
          break;
        case auth_error.notEnrolled:
          errorMessage = 'No biometrics are enrolled on this device';
          break;
        case auth_error.lockedOut:
          errorMessage = 'Biometric authentication is temporarily locked. Please try again later';
          break;
        case auth_error.permanentlyLockedOut:
          errorMessage = 'Biometric authentication is permanently locked. Please use your device password to re-enable it';
          break;
        case auth_error.passcodeNotSet:
          errorMessage = 'Device security is not enabled. Please enable it in your device settings';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred during biometric authentication';
      }
      
      Logger.error('Biometric authentication error', e);
      return (false, errorMessage);
    } catch (e, stack) {
      Logger.error('Unexpected biometric authentication error', e, stack);
      return (false, 'An unexpected error occurred during authentication');
    }
  }

  Future<void> _markAuthenticationTime() async {
    Logger.data('Marking authentication time');
    await _storage.write(
      key: _lastAuthTimeKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Future<bool> _isRecentlyAuthenticated() async {
    Logger.data('Checking recent authentication');
    final lastAuthTimeStr = await _storage.read(key: _lastAuthTimeKey);
    if (lastAuthTimeStr == null) {
      Logger.data('No recent authentication found');
      return false;
    }

    final lastAuthTime = DateTime.fromMillisecondsSinceEpoch(int.parse(lastAuthTimeStr));
    final now = DateTime.now();
    final difference = now.difference(lastAuthTime).inSeconds;

    final isRecent = difference < _authValidityDuration;
    Logger.data('Recent authentication check: $isRecent (${difference}s ago)');
    return isRecent;
  }

  Future<void> setPin(String pin) async {
    Logger.data('Setting new PIN');
    await _storage.write(key: _pinKey, value: pin);
    await _storage.write(key: _useBiometricKey, value: 'false');
    await _markAuthenticationTime();
    Logger.state('PIN set successfully');
  }

  Future<void> setBiometricEnabled() async {
    Logger.data('Enabling biometric authentication');
    final (isAuthenticated, error) = await authenticateWithBiometrics();
    if (!isAuthenticated) {
      Logger.error('Failed to enable biometric', error);
      throw Exception(error ?? 'Failed to enable biometric authentication');
    }
    await _storage.write(key: _useBiometricKey, value: 'true');
    await _markAuthenticationTime();
    Logger.state('Biometric enabled successfully');
  }

  Future<bool> verifyPin(String pin) async {
    Logger.interaction('Verifying PIN');
    final storedPin = await _storage.read(key: _pinKey);
    final isValid = storedPin == pin;
    Logger.state('PIN verification result: $isValid');
    if (isValid) {
      await _markAuthenticationTime();
    }
    return isValid;
  }

  Future<bool> usesBiometric() async {
    Logger.data('Checking if biometric is enabled');
    final value = await _storage.read(key: _useBiometricKey);
    final usesBiometric = value == 'true';
    Logger.data('Biometric enabled: $usesBiometric');
    return usesBiometric;
  }

  Future<bool> isSecuritySetup() async {
    Logger.data('Checking security setup');
    final usesBiometric = await this.usesBiometric();
    final hasPin = await _storage.read(key: _pinKey) != null;
    final isSetup = usesBiometric || hasPin;
    Logger.state('Security setup status: $isSetup (biometric: $usesBiometric, hasPin: $hasPin)');
    return isSetup;
  }

  Future<bool> requiresAuthentication() async {
    Logger.data('Checking if authentication is required');
    if (!await isSecuritySetup()) {
      Logger.state('No authentication required - security not setup');
      return false;
    }
    final requiresAuth = !await _isRecentlyAuthenticated();
    Logger.state('Authentication required: $requiresAuth');
    return requiresAuth;
  }

  Future<void> clearAllData() async {
    Logger.data('Starting data cleanup');
    
    try {
      Logger.data('Clearing all secure storage data');
      await _storage.deleteAll();
      
      Logger.data('Clearing all database tables');
      final dbHelper = DatabaseHelper();
      await dbHelper.clearAllTables();
      
      Logger.data('Cleaning up notification service');
      final notificationService = NotificationService();
      await notificationService.cleanup();
      
      Logger.state('All user data cleared successfully');
    } catch (e, stackTrace) {
      Logger.error('Error during data cleanup', e, stackTrace);
      throw Exception('Failed to clear user data: $e');
    }
  }
}
