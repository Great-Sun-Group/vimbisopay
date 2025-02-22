import 'dart:async' show StreamController;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/phone_formatter.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';

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

class _OTPVerificationFlowState extends State<OTPVerificationFlow>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  final _repository = ServiceLocator.accountRepository;
  bool _isLoading = false;
  String? _error;
  bool _isResending = false;
  late AnimationController _spinController;
  final _messageController = StreamController<String>.broadcast();

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
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
      barrierColor: Colors.black26,
      builder: (context) => LoadingDialog(
        spinController: _spinController,
        message: 'Verifying code...',
        messageStream: _messageController.stream,
      ),
    );

    try {
      final result = await _repository.verifyOtp(
        token: widget.token,
        otp: otp,
        memberId: widget.memberId,
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
                // Keep spinner running and update message
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
                      _error = failure.message ?? 'Failed to set password';
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
      barrierColor: Colors.black26,
      builder: (context) => LoadingDialog(
        spinController: _spinController,
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
      _spinController.stop();

      result.fold(
        (failure) {
          setState(() {
            _error = failure.message ?? 'Failed to resend OTP';
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
