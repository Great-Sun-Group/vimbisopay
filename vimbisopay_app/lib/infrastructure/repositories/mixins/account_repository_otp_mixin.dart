import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
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

  // setInitialPassword method removed as we're no longer using passwords

  // updatePassword method removed as we're no longer using passwords

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

  // resetPassword method removed as we're no longer using passwords
}
