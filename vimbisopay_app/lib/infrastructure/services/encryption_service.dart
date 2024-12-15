import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import '../../core/config/encryption_config.dart';
import 'security_service.dart';

class EncryptionService {
  final SecurityService _securityService;

  EncryptionService(this._securityService);

  Future<String?> _deriveKeyFromBiometric() async {
    // Check if biometric is enabled
    if (!await _securityService.usesBiometric()) {
      return null;
    }

    // Attempt biometric authentication
    final (authenticated, error) = await _securityService.authenticateWithBiometrics();
    if (!authenticated) {
      return null;
    }

    // Get PIN after successful biometric auth
    final pin = await _securityService.getSecurePin();
    if (pin == null) return null;
    
    // Create a key using PIN and prefix (we use PIN as the key material even with biometric auth)
    final keyData = utf8.encode(EncryptionConfig.keyPrefix + pin);
    final digest = sha256.convert(keyData);
    
    // Return first 32 bytes for AES-256
    return base64.encode(digest.bytes.sublist(0, 32));
  }

  Future<String> _deriveKeyFromPin() async {
    // Get PIN securely - this will now handle biometric/PIN fallback internally
    final pin = await _securityService.getSecurePin();
    if (pin == null) throw Exception('PIN not set');
    
    // Create a key using PIN and prefix
    final keyData = utf8.encode(EncryptionConfig.keyPrefix + pin);
    final digest = sha256.convert(keyData);
    
    // Return first 32 bytes for AES-256
    return base64.encode(digest.bytes.sublist(0, 32));
  }

  Future<String> _getEncryptionKey() async {
    // Try biometric first if enabled
    final biometricKey = await _deriveKeyFromBiometric();
    if (biometricKey != null) {
      return biometricKey;
    }
    
    // Fall back to PIN if biometric not available/enabled/failed
    return _deriveKeyFromPin();
  }

  Future<String> encryptToken(String token) async {
    try {
      // Get encryption key - this will try biometric first, then fall back to PIN
      final keyString = await _getEncryptionKey();
      final key = encrypt.Key.fromBase64(keyString);
      final iv = encrypt.IV.fromLength(16); // Generate random IV

      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(token, iv: iv);

      // Return IV + encrypted data
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      throw Exception('Failed to encrypt token: $e');
    }
  }

  Future<String> decryptToken(String encryptedToken) async {
    try {
      // Split IV and encrypted data
      final parts = encryptedToken.split(':');
      if (parts.length != 2) throw Exception('Invalid encrypted token format');

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

      // Get decryption key - this will try biometric first, then fall back to PIN
      final keyString = await _getEncryptionKey();
      final key = encrypt.Key.fromBase64(keyString);

      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('Failed to decrypt token: $e');
    }
  }
}
