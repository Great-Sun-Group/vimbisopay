import 'package:flutter/material.dart';
import 'package:vimbisopay_app/presentation/widgets/otp_verification_flow.dart';

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
    return OTPVerificationFlow(
      token: token,
      phone: phone,
      memberId: memberId,
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
