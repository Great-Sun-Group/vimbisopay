import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/services.dart';

class SecurityService {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;
  static const String _pinKey = 'user_pin';
  static const String _useBiometricKey = 'use_biometric';
  static const String _lastAuthTimeKey = 'last_auth_time';
  static const int _authValidityDuration = 30; // 5 minutes in seconds

  SecurityService()
      : _storage = const FlutterSecureStorage(),
        _localAuth = LocalAuthentication();

  Future<String?> getSecurePin() async {
    if (await requiresAuthentication()) {
      if (await usesBiometric()) {
        final (authenticated, _) = await authenticateWithBiometrics();
        if (authenticated) {
          return _storage.read(key: _pinKey);
        }
        // Biometric failed, check for valid PIN
      }
      
      // Check if we have a valid PIN
      final pin = await _storage.read(key: _pinKey);
      if (pin != null) {
        return pin;
      }
      
      // Both biometric and PIN checks failed
      throw Exception('Authentication required');
    }
    return _storage.read(key: _pinKey);
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        return false;
      }

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        return false;
      }

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } on PlatformException catch (e) {
      print('Error checking biometric availability: ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error checking biometric availability: $e');
      return false;
    }
  }

  Future<(bool, String?)> authenticateWithBiometrics() async {
    try {
      // Check if we have a recent successful authentication
      if (await _isRecentlyAuthenticated()) {
        return (true, null);
      }

      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return (false, 'Biometric authentication is not available on this device');
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

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
      
      return (false, errorMessage);
    } catch (e) {
      return (false, 'An unexpected error occurred during authentication');
    }
  }

  Future<void> _markAuthenticationTime() async {
    await _storage.write(
      key: _lastAuthTimeKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Future<bool> _isRecentlyAuthenticated() async {
    final lastAuthTimeStr = await _storage.read(key: _lastAuthTimeKey);
    if (lastAuthTimeStr == null) return false;

    final lastAuthTime = DateTime.fromMillisecondsSinceEpoch(int.parse(lastAuthTimeStr));
    final now = DateTime.now();
    final difference = now.difference(lastAuthTime).inSeconds;

    return difference < _authValidityDuration;
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
    await _storage.write(key: _useBiometricKey, value: 'false');
    await _markAuthenticationTime();
  }

  Future<void> setBiometricEnabled() async {
    final (isAuthenticated, error) = await authenticateWithBiometrics();
    if (!isAuthenticated) {
      throw Exception(error ?? 'Failed to enable biometric authentication');
    }
    await _storage.write(key: _useBiometricKey, value: 'true');
    await _markAuthenticationTime();
  }

  Future<bool> verifyPin(String pin) async {
    final storedPin = await _storage.read(key: _pinKey);
    final isValid = storedPin == pin;
    if (isValid) {
      await _markAuthenticationTime();
    }
    return isValid;
  }

  Future<bool> usesBiometric() async {
    final value = await _storage.read(key: _useBiometricKey);
    return value == 'true';
  }

  Future<bool> isSecuritySetup() async {
    final usesBiometric = await this.usesBiometric();
    final hasPin = await _storage.read(key: _pinKey) != null;
    return usesBiometric || hasPin;
  }

  Future<bool> requiresAuthentication() async {
    if (!await isSecuritySetup()) {
      return false;
    }
    return !await _isRecentlyAuthenticated();
  }
}
