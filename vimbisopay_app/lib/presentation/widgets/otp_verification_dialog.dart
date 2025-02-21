import 'dart:async' show StreamController, unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/phone_formatter.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart' show LoadingDialog;
import 'package:vimbisopay_app/presentation/screens/auth_screen.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';

class OTPVerificationDialog extends StatefulWidget {
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
  State<OTPVerificationDialog> createState() => _OTPVerificationDialogState();
}

class _OTPVerificationDialogState extends State<OTPVerificationDialog> with SingleTickerProviderStateMixin {
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

    // Store dialog context
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
          Navigator.of(dialogContext).pop(); // Pop loading dialog
          _spinController.stop();
          setState(() {
            _error = failure.message ?? 'Failed to verify OTP';
            _isLoading = false;
          });
        },
        (response) async {
          try {
            Logger.interaction('OTP verified successfully, setting up password');
            
            // Keep spinner running and update loading dialog message for password setup
            if (mounted) {
              _messageController.add('Setting up your password...');
            }

            Logger.data('Calling setInitialPassword with stored password');
            Logger.data('Current context: ${context.toString()}');
            Logger.data('Current route: ${ModalRoute.of(context)?.settings.name}');
            
            // Format phone number
            final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(widget.phone);
            Logger.data('[OTP_VERIFICATION] Formatted phone number: $formattedPhone');

            // Verify OTP response details
            if (!response.details.otpVerified) {
              throw Exception('OTP verification failed according to response');
            }

            try {
              final passwordResult = await _repository.setInitialPassword(
                token: widget.token,
                memberId: widget.memberId,
                phone: widget.phone,
                password: widget.password,
              );
              Logger.data('setInitialPassword result received');

              if (!mounted) return;

              passwordResult.fold(
                (failure) {
                  Logger.error('Failed to set password', failure);
                  if (failure.message?.toLowerCase().contains('token expired') == true) {
                    _error = 'Session expired. Please try again.';
                  } else {
                    _error = failure.message ?? 'Failed to set password';
                  }
                  Navigator.of(dialogContext).pop(); // Pop loading dialog
                  setState(() {
                    _isLoading = false;
                  });
                },
                (user) {
                  Logger.interaction('Password set successfully');
                  Logger.data('''
[OTP_VERIFICATION] Password set with v1 token:
- Token: ${user.token}
- Version: ${user.version}
- Auth Method: ${user.authMethod}
- OTP Verified: ${user.otpVerified}
''');
                  
                  // Pop loading dialog before navigation
                  Navigator.of(dialogContext).pop();
                  
                  // Navigate to auth screen with v1 token
                  _navigateToAuthScreen(user, dialogContext);
                },
              );
            } catch (e) {
              Logger.error('Error setting initial password', e);
              if (!mounted) return;
              Navigator.of(dialogContext).pop(); // Pop loading dialog
              setState(() {
                _error = 'Failed to set password. Please try again.';
                _isLoading = false;
              });
            }
          } catch (e) {
            Logger.error('Error setting password', e);
            if (!mounted) return;
            Navigator.of(dialogContext).pop(); // Pop loading dialog
            setState(() {
              _error = 'Failed to set password';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      Logger.error('Error verifying OTP', e);
      if (!mounted) return;
      Navigator.of(dialogContext).pop(); // Pop loading dialog
      setState(() {
        _error = 'An error occurred while verifying OTP';
        _isLoading = false;
      });
    }
  }

  void _navigateToAuthScreen(User user, BuildContext dialogContext) {
    // Navigate to auth screen, removing all previous routes
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/auth',
      (_) => false,
      arguments: user,
    );
    Logger.data('Navigation to auth screen completed');
  }

  Future<void> _resendOTP() async {
    setState(() {
      _isResending = true;
      _error = null;
    });

    // Store dialog context
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
      Navigator.of(dialogContext).pop(); // Pop loading dialog using stored context
      _spinController.stop();

      if (!mounted) return;

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
