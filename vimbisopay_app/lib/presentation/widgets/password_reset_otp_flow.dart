import 'dart:async' show StreamController;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/phone_formatter.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';
import 'package:vimbisopay_app/domain/entities/otp_verification_response.dart';

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

class _PasswordResetOTPFlowState extends State<PasswordResetOTPFlow>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  final _repository = ServiceLocator.accountRepository;
  bool _isLoading = false;
  String? _error;
  bool _isResending = false;
  late AnimationController _spinController;
  final _messageController = StreamController<String>.broadcast();
  String? _memberId;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
    
    // Initialize memberId from props
    _memberId = widget.memberId;
  }

  @override
  void dispose() {
    _otpController.dispose();
    _spinController.dispose();
    _messageController.close();
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _error = 'Please enter a valid 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final dialogContext = context;

    _spinController.repeat();
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      barrierColor: AppColors.barrierColor,
      builder: (context) => LoadingDialog(
        spinController: _spinController,
        message: 'Verifying code...',
        messageStream: _messageController.stream,
      ),
    );

    try {
      final result = await _repository.verifyOtp(
        token: '', // Empty token for password reset flow
        otp: otp,
        purpose: 'PASSWORD_RESET',
        memberId: _memberId,
      );

      if (!mounted) return;

      result.fold(
        (failure) {
          Navigator.of(dialogContext).pop();
          _spinController.stop();
          setState(() {
            _error = failure.message ?? 'Failed to verify OTP';
            _isLoading = false;
          });
        },
        (response) async {
          try {
            Logger.interaction('OTP verified successfully');

            if (!response.details.otpVerified) {
              throw Exception('OTP verification failed according to response');
            }

            // Pop loading dialog
            Navigator.of(dialogContext).pop();
            
            // Complete verification with response
            widget.onVerificationComplete(response);
          } catch (e) {
            Logger.error('Error completing verification', e);
            if (!mounted) return;
            Navigator.of(dialogContext).pop();
            setState(() {
              _error = 'Failed to complete verification';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      Logger.error('Error verifying OTP', e);
      if (!mounted) return;
      Navigator.of(dialogContext).pop();
      setState(() {
        _error = 'An error occurred while verifying OTP';
        _isLoading = false;
      });
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _isResending = true;
      _error = null;
    });

    final dialogContext = context;

    _spinController.repeat();
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      barrierColor: AppColors.barrierColor,
      builder: (context) => LoadingDialog(
        spinController: _spinController,
        message: _isResending ? 'Resending verification code...' : 'Sending verification code...',
        messageStream: _messageController.stream,
      ),
    );

    try {
      final sanitizedPhone = PhoneNumberFormatter.sanitizePhoneNumber(widget.phone);
      final result = await _repository.requestOtp(
        phone: sanitizedPhone,
        purpose: 'PASSWORD_RESET',
      );

      if (!mounted) return;
      Navigator.of(dialogContext).pop();
      _spinController.stop();

      result.fold(
        (failure) {
          setState(() {
            _error = failure.message ?? 'Failed to resend OTP';
          });
        },
        (response) {
          // Store memberId from response
          if (response['data']?['action']?['details']?['memberID'] != null) {
            setState(() {
              _memberId = response['data']['action']['details']['memberID'];
            });
            Logger.data('[REQUEST_OTP] Stored memberId: $_memberId');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isResending ? 'OTP has been resent' : 'OTP has been sent'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An error occurred while resending OTP';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Verify Phone Number',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: _isLoading
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                SizedBox(height: 16),
                Text(
                  'Verifying OTP...',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Please enter the 6-digit code sent to your phone number to verify your account.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otpController,
                    decoration: const InputDecoration(
                      labelText: 'Enter OTP',
                      prefixIcon: Icon(Icons.lock_outline),
                      helperText: 'Enter the 6-digit code',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _verifyOTP(),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isResending ? null : _resendOTP,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text(
                      _isResending ? 'Resending...' : 'Resend OTP',
                    ),
                  ),
                ],
              ),
            ),
      actions: _isLoading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _verifyOTP,
                child: const Text(
                  'Verify',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
    );
  }
}
