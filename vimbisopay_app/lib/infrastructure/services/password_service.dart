import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';

class PasswordService {
  final SecurityService _securityService;

  PasswordService() : _securityService = SecurityService();

  Future<bool> verifyPassword(String? username, String? password, String? deviceId) async {
    try {
      Logger.interaction('Verifying password');
      // In a real app, this would verify against the backend
      // For now, we'll just check if the user has a PIN set
      final hasPin = await _securityService.isSecuritySetup();
      return hasPin;
    } catch (e) {
      Logger.error('Error verifying password', e);
      return false;
    }
  }

  Future<({String hash, String salt})> hashPassword(String password) async {
    // Generate a random salt
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (i) => random.nextInt(256));
    final salt = base64.encode(saltBytes);

    // Hash the password with the salt
    final codec = Utf8Codec();
    final key = codec.encode(password);
    final saltedKey = key + saltBytes;
    final hash = sha256.convert(saltedKey);
    
    return (
      hash: base64.encode(hash.bytes),
      salt: salt,
    );
  }

  Future<void> changePassword(String newPassword) async {
    try {
      Logger.interaction('Changing password');
      // In a real app, this would update the password on the backend
      // For now, we'll just ensure security is set up
      if (!await _securityService.isSecuritySetup()) {
        await _securityService.setPin('0000'); // Default PIN for demo
      }
      Logger.state('Password changed successfully');
    } catch (e) {
      Logger.error('Error changing password', e);
      throw Exception('Failed to change password');
    }
  }
}
