import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';

class PasswordService {
  final DatabaseHelper _databaseHelper;
  final SecurityService _securityService;
  final http.Client _httpClient;

  PasswordService({http.Client? httpClient}) 
    : _databaseHelper = DatabaseHelper(),
      _securityService = SecurityService(),
      _httpClient = httpClient ?? http.Client();

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

  Future<String> hashPassword(String password) async {
    final codec = const Utf8Codec();
    final key = codec.encode(password);
    final hash = sha256.convert(key);
    return base64.encode(hash.bytes);
  }

  Map<String, String> get _baseHeaders => {
    'Content-Type': 'application/json',
    'x-client-api-key': ApiConfig.apiKey,
  };

  Map<String, String> _authHeaders(String token) => {
    ..._baseHeaders,
    'Authorization': 'Bearer $token',
  };

  Future<http.Response> _loggedRequest(
    Future<http.Response> Function() request,
    String url,
    String method, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      Logger.data('''
Making API request:
- URL: $url
- Method: $method
- Headers: $headers
- Body: $body
''');

      final response = await request();

      Logger.data('''
API response received:
- Status: ${response.statusCode}
- Body: ${response.body}
''');

      return response;
    } catch (e) {
      Logger.error('API request failed', e);
      rethrow;
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    Logger.interaction('Changing password');
    
    try {
      // Get current user to access stored password hash
      final user = await _databaseHelper.getUser();
      if (user == null) {
        throw Exception('Not authenticated');
      }

      if (user.passwordHash == null) {
        throw Exception('No stored password hash found');
      }

      // Verify current password
      final currentHash = await hashPassword(currentPassword);
      if (currentHash != user.passwordHash) {
        throw Exception('Current password is incorrect');
      }

      // Hash new password
      final newHash = await hashPassword(newPassword);

      final url = '${ApiConfig.baseUrl}/updatePassword';
      final headers = _authHeaders(user.token);
      final body = {
        'currentPassword': currentHash,
        'newPassword': newHash,
      };

      final response = await _loggedRequest(
        () => _httpClient.post(
          Uri.parse(url),
          headers: headers,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: headers,
        body: body,
      );

      if (response.statusCode != 200) {
        final errorMessage = json.decode(response.body)['message'] ?? 'Failed to change password';
        throw Exception(errorMessage);
      }

      // Update stored password hash
      final updatedUser = user.copyWith(
        passwordHash: newHash,
        passwordChanged: DateTime.now(),
      );
      await _databaseHelper.saveUser(updatedUser);

      Logger.state('Password changed successfully');
    } catch (e) {
      Logger.error('Error changing password', e);
      throw Exception('Failed to change password: ${e.toString()}');
    }
  }
}
