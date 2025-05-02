import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';

class OTPVerificationDialog extends StatefulWidget {
  final String token;
  final String phone;
  final String memberId;

  const OTPVerificationDialog({
    super.key,
    required this.token,
    required this.phone,
    required this.memberId,
  });

  @override
  State<OTPVerificationDialog> createState() => _OTPVerificationDialogState();
}

class _OTPVerificationDialogState extends State<OTPVerificationDialog> {
  final _otpController = TextEditingController();
  final _repository = ServiceLocator.accountRepository;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text;
    if (otp.isEmpty) {
      setState(() => _error = 'Please enter verification code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingDialog(
        message: 'Verifying code...',
      ),
    );

    try {
      final result = await _repository.verifyOtp(
        token: widget.token,
        otp: otp,
        purpose: 'PASSWORD_RESET',
        memberId: widget.memberId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Pop loading dialog

      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _error = failure.message ?? ErrorTranslator.translateError(failure);
          });
        },
        (response) async {
          // Login with phone number
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const LoadingDialog(
              message: 'Logging in...',
            ),
          );

          final loginResult = await _repository.login(
            phone: widget.phone,
          );

          if (!mounted) return;
          Navigator.of(context).pop(); // Pop loading dialog

          loginResult.fold(
            (failure) {
              setState(() {
                _isLoading = false;
                _error = failure.message ?? ErrorTranslator.translateError(failure);
              });
            },
            (user) {
              // Navigate to auth screen
              Navigator.pushReplacementNamed(
                context,
                '/auth',
                arguments: user,
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Pop loading dialog
      setState(() {
        _isLoading = false;
        _error = ErrorTranslator.translateError(e);
      });
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingDialog(
        message: 'Sending code...',
      ),
    );

    try {
      final result = await _repository.requestOtp(
        phone: widget.phone,
        purpose: 'PASSWORD_RESET',
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Pop loading dialog

      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _error = failure.message ?? ErrorTranslator.translateError(failure);
          });
        },
        (_) {
          setState(() {
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Pop loading dialog
      setState(() {
        _isLoading = false;
        _error = ErrorTranslator.translateError(e);
      });
    }
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
              'A verification code has been sent to your phone number ${widget.phone}',
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
              onPressed: _isLoading ? null : _verifyOTP,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                      ),
                    )
                  : const Text(
                      'Verify',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isLoading ? null : _resendOTP,
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                foregroundColor: AppColors.primary,
              ),
              child: const Text(
                'Resend Code',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
