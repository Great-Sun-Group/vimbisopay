import 'dart:convert';
import 'dart:math';
import 'package:pointycastle/export.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:flutter/foundation.dart';

class PasswordService {
  static const int SALT_LENGTH = 16;
  static const int HASH_LENGTH = 32;
  static const int ITERATIONS = 100000; // OWASP recommended minimum
  
  static ({String hash, String salt}) _hashPasswordSync(Map<String, dynamic> args) {
    final String password = args['password'];
    final String salt = args['salt'];
    
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(base64Decode(salt), ITERATIONS, HASH_LENGTH));
    final hash = pbkdf2.process(utf8.encode(password));
    
    return (hash: base64Encode(hash), salt: salt);
  }

  Future<({String hash, String salt})> hashPassword(String password) async {
    Logger.data('Generating password hash');
    try {
      final salt = _generateSalt();
      
      final result = await compute(_hashPasswordSync, {
        'password': password,
        'salt': salt,
      });
      
      Logger.data('Password hash generated successfully');
      return result;
    } catch (e) {
      Logger.error('Failed to hash password', e);
      throw Exception('Failed to hash password: $e');
    }
  }
  
  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(SALT_LENGTH, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }

  static bool _verifyPasswordSync(Map<String, dynamic> args) {
    final String password = args['password'];
    final String hash = args['hash'];
    final String salt = args['salt'];
    
    final hashBytes = base64Decode(hash);
    final saltBytes = base64Decode(salt);
    
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(saltBytes, ITERATIONS, HASH_LENGTH));
    final newHash = pbkdf2.process(utf8.encode(password));
    
    // Use constant-time comparison to prevent timing attacks
    if (hashBytes.length != newHash.length) {
      return false;
    }
    
    var result = 0;
    for (var i = 0; i < hashBytes.length; i++) {
      result |= hashBytes[i] ^ newHash[i];
    }
    
    return result == 0;
  }

  Future<bool> verifyPassword(String password, String hash, String salt) async {
    Logger.data('Verifying password');
    try {
      final isValid = await compute(_verifyPasswordSync, {
        'password': password,
        'hash': hash,
        'salt': salt,
      });
      
      Logger.data('Password verification result: $isValid');
      return isValid;
    } catch (e) {
      Logger.error('Failed to verify password', e);
      throw Exception('Failed to verify password: $e');
    }
  }
}
