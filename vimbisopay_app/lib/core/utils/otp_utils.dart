import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';

/// Utility class for OTP generation and WhatsApp deep linking
class OTPUtils {
  /// Get the appropriate WhatsApp phone number for the Vimbiso chatbot based on environment
  static String get chatbotNumber {
    // Use different numbers for production and development/demo environments
    final isProd = ApiConfig.environmentName.toLowerCase() == 'production';
    
    // Production: 263785304448, Development/Demo: 263787274250
    final number = isProd ? '263785304448' : '263787274250';
    
    Logger.data('[OTP_UTILS] Using ${isProd ? "production" : "development"} chatbot number: $number');
    return number;
  }

  /// Generates a random 6-digit OTP
  /// 
  /// Returns a string containing a 6-digit numeric code
  static String generateOTP() {
    final random = Random.secure();
    final otp = List.generate(6, (_) => random.nextInt(10)).join();
    Logger.data('[OTP_UTILS] Generated OTP: $otp');
    return otp;
  }

  /// Creates a WhatsApp deep link with a pre-populated verification message
  /// 
  /// [otp] The OTP to include in the message
  /// Returns a URI for the WhatsApp deep link
  static Uri createWhatsAppDeepLink(String otp) {
    final message = 'VERIFY $otp';
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/$chatbotNumber?text=$encodedMessage';
    Logger.data('[OTP_UTILS] Created WhatsApp deep link: $url');
    return Uri.parse(url);
  }

  /// Creates a deep link back to the app for verification completion
  /// 
  /// [phone] The phone number to include in the deep link
  /// Returns a URI for the app deep link
  static String createAppDeepLink(String phone) {
    final encodedPhone = Uri.encodeComponent(phone);
    final url = 'vimbisopay://verification-complete?phone=$encodedPhone&status=success';
    Logger.data('[OTP_UTILS] Created app deep link: $url');
    return url;
  }

  /// Opens WhatsApp with a pre-populated verification message
  /// 
  /// [otp] The OTP to include in the message
  /// Returns a Future<bool> indicating whether the link was successfully opened
  static Future<bool> openWhatsAppWithOTP(String otp) async {
    try {
      final uri = createWhatsAppDeepLink(otp);
      Logger.interaction('[OTP_UTILS] Opening WhatsApp with OTP: $otp');
      
      // Check if the URL can be launched
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        Logger.error('[OTP_UTILS] Cannot launch WhatsApp URL', 'URL: $uri');
        return false;
      }
    } catch (e) {
      Logger.error('[OTP_UTILS] Error opening WhatsApp', e);
      return false;
    }
  }
}
