import 'dart:math';
import 'package:vimbisopay_app/core/utils/logger.dart';

/// Utility class for generating OTPs and creating WhatsApp deep links
class OtpGenerator {
  /// The Vimbiso chatbot WhatsApp number
  static const String chatbotNumber = '263785304448';

  /// Generates a random 6-digit OTP
  /// 
  /// Returns a string containing the generated OTP
  static String generateOTP() {
    final random = Random.secure();
    final otp = random.nextInt(900000) + 100000; // Ensures 6 digits
    Logger.data('[OTP_GENERATOR] Generated OTP: $otp');
    return otp.toString();
  }

  /// Creates a WhatsApp deep link with a pre-populated verification message
  /// 
  /// [otp] The OTP to include in the message
  /// Returns a URI that can be launched to open WhatsApp with the message
  static Uri createWhatsAppDeepLink(String otp) {
    final message = 'VERIFY $otp';
    final encodedMessage = Uri.encodeComponent(message);
    final deepLink = 'https://wa.me/$chatbotNumber?text=$encodedMessage';
    Logger.data('[OTP_GENERATOR] Created WhatsApp deep link: $deepLink');
    return Uri.parse(deepLink);
  }

  /// Creates a WhatsApp deep link with a pre-populated verification message
  /// and returns it as a string
  /// 
  /// [otp] The OTP to include in the message
  /// Returns a string containing the WhatsApp deep link
  static String createWhatsAppDeepLinkString(String otp) {
    return createWhatsAppDeepLink(otp).toString();
  }
}
