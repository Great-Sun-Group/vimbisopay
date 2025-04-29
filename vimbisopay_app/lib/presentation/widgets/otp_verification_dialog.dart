import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/presentation/widgets/whatsapp_otp_verification.dart';

class OTPVerificationDialog extends StatelessWidget {
  final String token;
  final String phone;
  final String memberId;
  final String password;

  const OTPVerificationDialog({
    super.key,
    required this.token,
    required this.phone,
    required this.memberId,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    Logger.data('[OTP_DIALOG] Using WhatsApp OTP verification');
    
    // Use the WhatsApp OTP verification flow
    return WhatsAppOTPVerification(
      token: token,
      phone: phone,
      memberId: memberId,
      password: password,
      onVerificationComplete: (user) {
        // Navigate to auth screen
        Navigator.pushReplacementNamed(
          context,
          '/auth',
          arguments: user,
        );
      },
    );
  }
}
