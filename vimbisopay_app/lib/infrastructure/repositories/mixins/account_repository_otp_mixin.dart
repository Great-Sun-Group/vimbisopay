import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/otp_verification_response.dart';
import 'package:vimbisopay_app/domain/entities/verification_status.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';
import 'package:vimbisopay_app/core/utils/phone_formatter.dart';
import 'package:vimbisopay_app/infrastructure/repositories/base_account_repository.dart';

/// Mixin that provides OTP and password-related methods for AccountRepositoryImpl
mixin AccountRepositoryOtpMixin on BaseAccountRepository {
  
  @override
  Future<Either<Failure, Map<String, dynamic>>> storeOtp({
    required String memberId,
    required String phone,
    required String otp,
    required String purpose,
  }) async {
    try {
      // Format phone number before sending
      final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      Logger.data('[STORE_OTP] Formatted phone number: $formattedPhone');
      Logger.data('[STORE_OTP] Storing OTP for member: $memberId, purpose: $purpose');
      
      // WhatsApp verification should not require authentication
      final url = '$baseUrl/verify/storeOtp';
      final headers = baseHeaders; // Use base headers without authentication
      final body = {
        'memberID': memberId,
        'phone': formattedPhone,
        'otp': otp,
        'purpose': purpose,
      };

      final response = await loggedRequest(
        () => httpClient.post(
          Uri.parse(url),
          headers: headers,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (!jsonResponse.containsKey('data') ||
            !jsonResponse['data'].containsKey('action')) {
          return const Left(InfrastructureFailure('Invalid response format'));
        }

        // Extract verification token and expiry from response
        final actionDetails = jsonResponse['data']['action']['details'];
        final verificationToken = actionDetails['verificationToken'] as String?;
        final expiresIn = actionDetails['expiresIn'] as int?;
        
        if (verificationToken == null) {
          Logger.error('[STORE_OTP] Missing verification token in response');
          return const Left(InfrastructureFailure('Missing verification token in response'));
        }
        
        Logger.data('[STORE_OTP] OTP stored successfully with token: [REDACTED]');
        return Right({
          'verificationToken': verificationToken,
          'expiresIn': expiresIn ?? 300, // Default to 5 minutes if not provided
        });
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Failed to store OTP';
        Logger.error('[STORE_OTP] Failed to store OTP', errorMessage);
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      final userFriendlyMessage = ErrorTranslator.translateError(e);
      Logger.error('[STORE_OTP] Error storing OTP', e);
      return Left(InfrastructureFailure(userFriendlyMessage));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    try {
      final sanitizedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      final url = '$baseUrl/verify/requestOtp';
      final body = {
        'phone': sanitizedPhone,
        'purpose': purpose,
      };

      Logger.data('[REQUEST_OTP] Sending request for phone: $sanitizedPhone, purpose: $purpose');
      final response = await loggedRequest(
        () => httpClient.post(
          Uri.parse(url),
          headers: baseHeaders,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: baseHeaders,
        body: body,
      );

      if (response.statusCode == 200) {
        Logger.data('[REQUEST_OTP] Request successful');
        final jsonResponse = json.decode(response.body);
        return Right(jsonResponse);
      } else {
        final responseBody = json.decode(response.body);
        final errorMessage = responseBody['message'] ?? 'Failed to request OTP';
        
        // Extract error code if available
        String? errorCode;
        if (responseBody.containsKey('data') && 
            responseBody['data'].containsKey('action') &&
            responseBody['data']['action'].containsKey('details')) {
          errorCode = responseBody['data']['action']['details']['code'];
          final reason = responseBody['data']['action']['details']['reason'];
          Logger.error('[REQUEST_OTP] Request failed with code: $errorCode', 'Reason: $reason');
        } else {
          Logger.error('[REQUEST_OTP] Request failed', errorMessage);
        }
        
        return Left(InfrastructureFailure(errorMessage, errorCode));
      }
    } catch (e) {
      Logger.error('[REQUEST_OTP] Exception occurred', e);
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OtpVerificationResponse>> verifyOtp({
    required String token,
    required String otp,
    required String purpose,
    String? memberId,
  }) async {
    try {
      final url = '$baseUrl/verify/verifyOtp';
      // WhatsApp verification should not require authentication
      final headers = baseHeaders; // Use base headers without authentication
      final body = {
        'otp': otp,
        'purpose': purpose,
        'token': token, // Include token in the body instead of headers
      };

      // Only include memberId if provided
      if (memberId != null) {
        body['memberID'] = memberId;
      }

      Logger.data('[VERIFY_OTP] Sending request...');
      final response = await loggedRequest(
        () => httpClient.post(
          Uri.parse(url),
          headers: headers,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: headers,
        body: body,
      );

      Logger.data('''
[VERIFY_OTP] Response received:
Status code: ${response.statusCode}
Response body: ${response.body}
''');

      if (response.statusCode == 200) {
        Logger.data('[VERIFY_OTP] Request successful, parsing response');
        final jsonResponse = json.decode(response.body);
        return Right(OtpVerificationResponse.fromJson(jsonResponse));
      } else {
        final responseBody = json.decode(response.body);
        final errorMessage = responseBody['message'] ?? 'Failed to verify OTP';
        
        // Extract error code if available
        String? errorCode;
        if (responseBody.containsKey('data') && 
            responseBody['data'].containsKey('action') &&
            responseBody['data']['action'].containsKey('details')) {
          errorCode = responseBody['data']['action']['details']['code'];
          final reason = responseBody['data']['action']['details']['reason'];
          Logger.error('[VERIFY_OTP] Request failed with code: $errorCode', 'Reason: $reason');
        } else {
          Logger.error('[VERIFY_OTP] Request failed', errorMessage);
        }
        
        return Left(InfrastructureFailure(errorMessage, errorCode));
      }
    } catch (e) {
      Logger.error('[VERIFY_OTP] Exception occurred', e);
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> setInitialPassword({
    required String token,
    required String memberId,
    required String phone,
    required String password,
  }) async {
    try {
      Logger.data('[SET_INITIAL_PASSWORD] Starting password setup');
      
      final url = '$baseUrl/setInitialPassword';
      final headers = authHeaders(token);
      
      // Format phone number
      final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      
      // Hash password and prepare body
      final hashedPassword = await passwordService.hashPassword(password);
      final body = {
        'phone': formattedPhone,
        'password': hashedPassword,
        'memberID': memberId,
      };

      Logger.data('''
[SET_INITIAL_PASSWORD] Request details:
URL: $url
Headers: ${headers.map((k, v) => MapEntry(k, k == 'Authorization' ? 'Bearer [REDACTED]' : v))}
Request body (redacted):
${{'phone': formattedPhone, 'password': '[REDACTED]', 'memberID': memberId}}
Using token from v1 login: ${token.substring(0, 10)}...
''');
      final response = await loggedRequest(
        () => httpClient.post(
          Uri.parse(url),
          headers: headers,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: headers,
        body: body,
      );

      Logger.data('''
[SET_INITIAL_PASSWORD] Response received:
Status code: ${response.statusCode}
Response body: ${response.body}
''');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        Logger.data('[SET_INITIAL_PASSWORD] Response parsed successfully');
        
        if (!jsonResponse.containsKey('data')) {
          Logger.error('[SET_INITIAL_PASSWORD] Invalid response format: Missing data field');
          return const Left(InfrastructureFailure('Invalid response format: Missing data field'));
        }
        
        if (!jsonResponse['data'].containsKey('action')) {
          Logger.error('[SET_INITIAL_PASSWORD] Invalid response format: Missing action field');
          return const Left(InfrastructureFailure('Invalid response format: Missing action field'));
        }
        
        if (!jsonResponse['data']['action'].containsKey('details')) {
          Logger.error('[SET_INITIAL_PASSWORD] Invalid response format: Missing details field');
          return const Left(InfrastructureFailure('Invalid response format: Missing details field'));
        }

        final actionDetails = jsonResponse['data']['action']['details'];
        final memberId = actionDetails['memberID']?.toString();
        final userPhone = actionDetails['phone']?.toString();
        final token = actionDetails['token']?.toString();

        if (memberId == null || userPhone == null || token == null) {
          return const Left(InfrastructureFailure('Missing required user fields in response'));
        }

        Logger.data('[SET_INITIAL_PASSWORD] Password set successfully, proceeding with v2 login');
        
        // Get existing user to preserve store status and location
        final existingUser = await databaseHelper.getUser();
        
        // Immediately perform v2 login with the new password hash
        final loginResult = await loginV2(
          phone: formattedPhone,
          passwordHash: hashedPassword,
        );
        
        // If we have an existing user and the login was successful, ensure we preserve the store status and location
        if (existingUser != null) {
          return loginResult.fold(
            (failure) => Left(failure),
            (newUser) async {
              // Create updated user with preserved store status and location
              final updatedUser = newUser.copyWith(
                storeOpen: existingUser.storeOpen,
                latitude: existingUser.latitude,
                longitude: existingUser.longitude,
              );
              
              // Save the updated user
              await databaseHelper.saveUser(updatedUser);
              
              Logger.data('[SET_INITIAL_PASSWORD] Preserved store status: ${updatedUser.storeOpen}');
              if (updatedUser.latitude != null && updatedUser.longitude != null) {
                Logger.data('[SET_INITIAL_PASSWORD] Preserved location: (${updatedUser.latitude}, ${updatedUser.longitude})');
              }
              
              return Right(updatedUser);
            },
          );
        }
        
        return loginResult;
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Failed to set initial password';
        Logger.error('Failed to set initial password', errorMessage);
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      Logger.error('Error setting initial password', e);
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/updatePassword';
        final headers = authHeaders(token);

        // Get current user to verify password hash
        final user = await databaseHelper.getUser();
        if (user == null) {
          return const Left(InfrastructureFailure('Not authenticated'));
        }

        // Hash both passwords
        final currentHash = await passwordService.hashPassword(currentPassword);
        final newHash = await passwordService.hashPassword(newPassword);

        // Verify current password matches stored hash
        if (user.passwordHash != null && currentHash != user.passwordHash) {
          return const Left(AuthFailure(
            message: 'Current password is incorrect',
            code: 'INVALID_PASSWORD',
          ));
        }

        final body = {
          'currentPassword': currentHash,
          'newPassword': newHash,
        };

        final response = await loggedRequest(
          () => httpClient.post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          ),
          url,
          'POST',
          headers: headers,
          body: body,
        );

        if (response.statusCode == 200) {
          // Update stored password hash while preserving store status and location
          final updatedUser = user.copyWith(
            passwordHash: newHash,
            passwordChanged: DateTime.now(),
            // No need to explicitly set storeOpen, latitude, and longitude
            // as copyWith will preserve them from the original user object
          );
          
          Logger.data('[UPDATE_PASSWORD] Preserved store status: ${updatedUser.storeOpen}');
          if (updatedUser.latitude != null && updatedUser.longitude != null) {
            Logger.data('[UPDATE_PASSWORD] Preserved location: (${updatedUser.latitude}, ${updatedUser.longitude})');
          }
          await databaseHelper.saveUser(updatedUser);
          
          return const Right(true);
        } else {
          final errorMessage = json.decode(response.body)['message'] ?? 'Failed to update password';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }

  @override
  Future<Either<Failure, VerificationStatus>> checkOtpVerificationStatus({
    required String phone,
  }) async {
    try {
      // Format phone number before sending
      final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      Logger.data('[CHECK_OTP_STATUS] Checking OTP verification status for phone: $formattedPhone');
      
      // WhatsApp verification should not require authentication
      final url = '$baseUrl/verify/checkOtpStatus?phone=$formattedPhone';
      final headers = baseHeaders; // Use base headers without authentication

      final response = await loggedRequest(
        () => httpClient.get(
          Uri.parse(url),
          headers: headers,
        ),
        url,
        'GET',
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (!jsonResponse.containsKey('data') ||
            !jsonResponse['data'].containsKey('action') ||
            !jsonResponse['data']['action'].containsKey('details')) {
          return const Left(InfrastructureFailure('Invalid response format'));
        }

        final details = jsonResponse['data']['action']['details'];
        final verified = details['verified'] as bool? ?? false;
        
        // Extract verification token and expiry if available
        final verificationToken = details['verificationToken'] as String?;
        final expiresIn = details['expiresIn'] as int?;
        
        // Parse verifiedAt if available
        DateTime? verifiedAt;
        if (details['verifiedAt'] != null) {
          try {
            verifiedAt = DateTime.parse(details['verifiedAt'] as String);
          } catch (e) {
            Logger.error('[CHECK_OTP_STATUS] Failed to parse verifiedAt', e);
          }
        }
        
        final status = VerificationStatus(
          verified: verified,
          verifiedAt: verifiedAt,
          verificationToken: verificationToken,
          expiresIn: expiresIn,
        );
        
        Logger.data('[CHECK_OTP_STATUS] OTP verification status: $status');
        return Right(status);
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Failed to check OTP verification status';
        Logger.error('[CHECK_OTP_STATUS] Failed to check OTP verification status', errorMessage);
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      final userFriendlyMessage = ErrorTranslator.translateError(e);
      Logger.error('[CHECK_OTP_STATUS] Error checking OTP verification status', e);
      return Left(InfrastructureFailure(userFriendlyMessage));
    }
  }

  @override
  Future<bool> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final url = '$baseUrl/resetPassword';
      final headers = baseHeaders;

      // Hash the new password before sending
      final hashedPassword = await passwordService.hashPassword(newPassword);
      
      final body = {
        'verificationToken': resetToken, // Changed from resetToken to verificationToken
        'newPassword': hashedPassword,
      };

      final response = await loggedRequest(
        () => httpClient.post(
          Uri.parse(url),
          headers: headers,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        Logger.data('[RESET_PASSWORD] Password reset successful');
        return true;
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Failed to reset password';
        return false;
      }
    } catch (e) {
      Logger.error('Error resetting password', e);
      return false;
    }
  }
}
