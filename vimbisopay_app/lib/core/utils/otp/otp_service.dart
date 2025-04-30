import 'package:dartz/dartz.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/otp/otp_generator.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

/// Service for handling user-initiated OTP verification
class OtpService {
  /// Generates an OTP, stores it in Credex Core, and creates a WhatsApp deep link
  /// 
  /// [memberId] The member's ID
  /// [phone] The phone number to associate with the OTP
  /// [purpose] The purpose of the OTP (e.g., 'PASSWORD_RESET')
  /// 
  /// Returns Either a Failure or a WhatsApp deep link URI
  static Future<Either<Failure, Uri>> generateAndStoreOTP({
    required String memberId,
    required String phone,
    required String purpose,
  }) async {
    try {
      // Generate OTP
      final otp = OtpGenerator.generateOTP();
      Logger.data('[OTP_SERVICE] Generated OTP for $memberId: $otp');
      
      // Store OTP in Credex Core
      final repository = ServiceLocator.accountRepository;
      final result = await repository.storeOtp(
        memberId: memberId,
        phone: phone,
        otp: otp,
        purpose: purpose,
      );
      
      return result.fold(
        (failure) {
          Logger.error('[OTP_SERVICE] Failed to store OTP', failure);
          return Left(failure);
        },
        (_) {
          // Create WhatsApp deep link
          final deepLink = OtpGenerator.createWhatsAppDeepLink(otp);
          Logger.data('[OTP_SERVICE] Created WhatsApp deep link: $deepLink');
          return Right(deepLink);
        },
      );
    } catch (e) {
      Logger.error('[OTP_SERVICE] Error in generateAndStoreOTP', e);
      return Left(InfrastructureFailure('Failed to generate and store OTP: ${e.toString()}'));
    }
  }
  
  /// Opens WhatsApp with a pre-populated verification message
  /// 
  /// [deepLink] The WhatsApp deep link URI
  /// 
  /// Returns true if WhatsApp was opened successfully, false otherwise
  static Future<bool> openWhatsAppWithOTP(Uri deepLink) async {
    try {
      Logger.data('[OTP_SERVICE] Opening WhatsApp with deep link: $deepLink');
      final canLaunch = await canLaunchUrl(deepLink);
      
      if (canLaunch) {
        final result = await launchUrl(
          deepLink,
          mode: LaunchMode.externalApplication,
        );
        Logger.data('[OTP_SERVICE] WhatsApp launch result: $result');
        return result;
      } else {
        Logger.error('[OTP_SERVICE] Cannot launch WhatsApp', 'URL cannot be launched: $deepLink');
        return false;
      }
    } catch (e) {
      Logger.error('[OTP_SERVICE] Error opening WhatsApp', e);
      return false;
    }
  }
}
