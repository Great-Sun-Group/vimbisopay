import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';
import 'package:vimbisopay_app/presentation/widgets/whatsapp_otp_verification.dart';
import 'package:vimbisopay_app/domain/entities/otp_verification_response.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';

class PasswordResetOTPFlow extends StatefulWidget {
  final String phone;
  final String memberId;
  final Function(OtpVerificationResponse) onVerificationComplete;

  const PasswordResetOTPFlow({
    super.key,
    required this.phone,
    required this.memberId,
    required this.onVerificationComplete,
  });

  @override
  State<PasswordResetOTPFlow> createState() => _PasswordResetOTPFlowState();
}

class _PasswordResetOTPFlowState extends State<PasswordResetOTPFlow> {
  final _otpController = TextEditingController();
  final _messageController = StreamController<String>.broadcast();
  final _repository = ServiceLocator.accountRepository;
  bool _isResending = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    _messageController.close();
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text;
    if (otp.isEmpty) {
      setState(() => _error = 'Please enter verification code');
      return;
    }

    setState(() => _error = null);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LoadingDialog(
        message: 'Verifying code...',
        messageStream: _messageController.stream,
      ),
    );

    // For PASSWORD_RESET purpose, we don't use the token
    final result = await _repository.verifyOtp(
      token: '', // Empty token for PASSWORD_RESET
      otp: otp,
      purpose: 'PASSWORD_RESET',
      memberId: widget.memberId,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // Pop loading dialog

    result.fold(
      (failure) {
        setState(() {
          if (failure is InfrastructureFailure && failure.code == 'RATE_LIMITED') {
            // Extract the wait time from the error message if available
            final reason = failure.message?.contains('Try again in') == true 
                ? failure.message 
                : 'Please wait before verifying another OTP';
            _error = reason;
            Logger.data('[VERIFY_OTP] Rate limited: $reason');
          } else {
            _error = failure.message ?? ErrorTranslator.translateError(failure);
          }
        });
      },
      (response) {
        widget.onVerificationComplete(response);
      },
    );
  }

  Future<void> _resendOTP() async {
    // Replace with WhatsApp OTP verification
    Navigator.of(context).pop(); // Close the current dialog
    
    // Show WhatsApp OTP verification dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WhatsAppOTPVerification(
        token: '',
        phone: widget.phone,
        memberId: widget.memberId,
        onVerificationComplete: widget.onVerificationComplete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.message_outlined,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'Enter Verification Code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'A verification code has been sent to your WhatsApp number ${widget.phone}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              decoration: InputDecoration(
                labelText: 'Verification Code',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _verifyOTP,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Verify',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _resendOTP,
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                foregroundColor: AppColors.primary,
              ),
              child: Text(
                _isResending ? 'Resending...' : 'Resend Code',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
