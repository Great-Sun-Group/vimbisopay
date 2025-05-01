import 'package:flutter/material.dart';
import 'package:vimbisopay_app/presentation/widgets/whatsapp_otp_verification.dart';

class TestWhatsAppOTP extends StatelessWidget {
  const TestWhatsAppOTP({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test WhatsApp OTP'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => WhatsAppOTPVerification(
                token: 'test-token',
                phone: '263785304448',
                memberId: 'test-member-id',
                onVerificationComplete: (user) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification complete!'),
                    ),
                  );
                },
              ),
            );
          },
          child: const Text('Show WhatsApp OTP Dialog'),
        ),
      ),
    );
  }
}
