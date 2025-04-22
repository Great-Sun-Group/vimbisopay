import 'dart:async' show StreamController;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/phone_formatter.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';

class OTPVerificationFlow extends StatefulWidget {
  final String token;
  final String phone;
  final String memberId;
  final User? user; // Optional user object for v2 flow
  final String? password; // Optional password for v1->v2 migration
  final bool isAccountCreation; // Flag to indicate if this is for account creation
  final Function(User) onVerificationComplete;

  const OTPVerificationFlow({
    super.key,
    required this.token,
    required this.phone,
    required this.memberId,
    required this.onVerificationComplete,
    this.user,
    this.password,
    this.isAccountCreation = false,
  });

  @override
  State<OTPVerificationFlow> createState() => _OTPVerificationFlowState();
}

class _OTPVerificationFlowState extends State<OTPVerificationFlow> {
  final _otpController = TextEditingController();
  final _repository = ServiceLocator.accountRepository;
  final _messageController = StreamController<String>.broadcast();
  bool _isLoading = false;
  String? _error;
  bool _isResending = false;

  @override
  void dispose() {
    _otpController.dispose();
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

    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      barrierColor: AppColors.barrierColor,
      builder: (context) => LoadingDialog(
        message: 'Verifying code...',
        messageStream: _messageController.stream,
      ),
    );

    try {
      final result = await _repository.verifyOtp(
        token: widget.token,
        otp: otp,
        memberId: widget.memberId,
        purpose: widget.isAccountCreation ? 'PASSWORD_RESET' : 'PASSWORD_RESET',
      );

      if (!mounted) return;

      result.fold(
        (failure) {
          Navigator.of(dialogContext).pop();
          setState(() {
            // Check for daily limit errors first
            if (ErrorTranslator.isDailyLimitError(failure)) {
              _error = ErrorTranslator.getDailyLimitErrorMessage();
              Logger.data('[VERIFY_OTP] Daily limit exceeded: ${failure.message}');
            } 
            // Check for rate limiting
            else if (failure is InfrastructureFailure && failure.code == 'RATE_LIMITED') {
              // Regular rate limiting
              final reason = failure.message?.contains('Try again in') == true 
                  ? failure.message 
                  : 'Please wait before verifying another OTP';
              _error = reason;
              Logger.data('[VERIFY_OTP] Rate limited: $reason');
            } 
            // Default error handling
            else {
              _error = failure.message ?? ErrorTranslator.translateError(failure);
            }
            _isLoading = false;
          });
        },
        (response) async {
          try {
            Logger.interaction('OTP verified successfully');

            if (!response.details.otpVerified) {
              throw Exception('OTP verification failed according to response');
            }

            // Handle different flows based on context
            if (widget.user != null) {
              // For v2 login flow, we already have a user object
              final verifiedUser = widget.user!.copyWith(
                otpVerified: true,
              );
              
              // Save updated user
              await _repository.saveUser(verifiedUser);
              
              // Pop loading dialog
              Navigator.of(dialogContext).pop();
              
              // Complete verification
              widget.onVerificationComplete(verifiedUser);
            } else if (widget.isAccountCreation) {
              // For account creation flow, preserve full user data and just update otpVerified
              if (widget.user == null) {
                throw Exception('User object is required for account creation flow');
              }
              
              final verifiedUser = widget.user!.copyWith(
                otpVerified: true,
              );
              
              // Save user with all data preserved
              await _repository.saveUser(verifiedUser);
              
              // Pop loading dialog
              Navigator.of(dialogContext).pop();
              
              // Complete verification
              widget.onVerificationComplete(verifiedUser);
            } else {
              // For v1->v2 migration flow, we need to set initial password
              // Update message
              _messageController.add('Setting up password...');

              if (widget.password == null) {
                throw Exception('Password is required for v1->v2 migration');
              }
              
              final setPasswordResult = await _repository.setInitialPassword(
                token: widget.token,
                memberId: widget.memberId,
                phone: widget.phone,
                password: widget.password!,
              );

              if (!mounted) return;

              setPasswordResult.fold(
                (failure) {
                  Logger.error('Failed to set initial password', failure);
                  Navigator.of(dialogContext).pop();
                  setState(() {
                    _error = failure.message ?? ErrorTranslator.translateError(failure);
                    _isLoading = false;
                  });
                },
                (user) {
                  Logger.interaction('Password setup completed successfully');
                  
                  // Pop loading dialog
                  Navigator.of(dialogContext).pop();
                  
                  // Complete verification with v2 user
                  widget.onVerificationComplete(user);
                },
              );
            }
          } catch (e) {
            Logger.error('Error completing verification', e);
            if (!mounted) return;
            Navigator.of(dialogContext).pop();
            setState(() {
              _error = ErrorTranslator.translateError(e);
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
        _error = ErrorTranslator.translateError(e);
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

    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      barrierColor: AppColors.barrierColor,
      builder: (context) => LoadingDialog(
        message: 'Resending verification code...',
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

      result.fold(
        (failure) {
          setState(() {
            // Check for daily limit errors first
            if (ErrorTranslator.isDailyLimitError(failure)) {
              _error = ErrorTranslator.getDailyLimitErrorMessage();
              Logger.data('[RESEND_OTP] Daily limit exceeded: ${failure.message}');
            } 
            // Check for rate limiting
            else if (failure is InfrastructureFailure && failure.code == 'RATE_LIMITED') {
              // Regular rate limiting
              final reason = failure.message?.contains('Try again in') == true 
                  ? failure.message 
                  : 'Please wait before requesting another OTP';
              _error = reason;
              Logger.data('[RESEND_OTP] Rate limited: $reason');
            } 
            // Default error handling
            else {
              _error = failure.message ?? ErrorTranslator.translateError(failure);
            }
          });
        },
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP has been resent'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorTranslator.translateError(e);
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
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
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Please enter the 6-digit code sent to your Whatsapp phone number to verify your account.',
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
                          overflow: TextOverflow.visible,
                          softWrap: true,
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
                style: ButtonStyle(
                  minimumSize: MaterialStateProperty.all(const Size(80, 36)),
                  padding: MaterialStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
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
