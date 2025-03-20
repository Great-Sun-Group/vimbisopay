import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/password_validator.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';

class ResetPasswordFlow extends StatefulWidget {
  final String resetToken;
  final String phone;
  final String memberId;
  final Function onResetComplete;

  const ResetPasswordFlow({
    super.key,
    required this.resetToken,
    required this.phone,
    required this.memberId,
    required this.onResetComplete,
  });

  @override
  State<ResetPasswordFlow> createState() => _ResetPasswordFlowState();
}

class _ResetPasswordFlowState extends State<ResetPasswordFlow> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _repository = ServiceLocator.accountRepository;
  final _messageController = StreamController<String>.broadcast();
  String? _error;
  double _passwordStrength = 0.0;
  String _strengthText = 'Too weak';
  Color _strengthColor = AppColors.error;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _messageController.close();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _newPasswordController.text;
    final strength = PasswordValidator.calculateStrength(password);
    setState(() {
      _passwordStrength = strength;
      if (strength < 0.3) {
        _strengthText = 'Too weak';
        _strengthColor = AppColors.error;
      } else if (strength < 0.7) {
        _strengthText = 'Moderate';
        _strengthColor = Colors.orange;
      } else {
        _strengthText = 'Strong';
        _strengthColor = AppColors.success;
      }
    });
  }

  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Reset error state
    setState(() {
      _error = null;
    });

    // Validate passwords
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _error = 'Please fill in both password fields';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _error = 'Passwords do not match';
      });
      return;
    }

    final validation = PasswordValidator.validatePassword(newPassword);
    if (!validation.isValid) {
      setState(() {
        _error = validation.error;
      });
      return;
    }

    final dialogContext = context;

    // Show loading dialog
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      barrierColor: AppColors.barrierColor,
      builder: (context) => LoadingDialog(
        message: 'Resetting password...',
        messageStream: _messageController.stream,
      ),
    );

    try {
      final result = await _repository.resetPassword(
        resetToken: widget.resetToken,
        newPassword: newPassword,
      );

      if (!mounted) return;

      if (result) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 28,
            ),
            title: const Text(
              'Password Reset Successful',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            content: const Text(
              'Your password has been reset successfully.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            actions: [
              TextButton(
                onPressed: () {
                  Logger.interaction(
                      '[ResetPassword] Success dialog OK pressed, navigating to login');
                  // Pop the success dialog using its own context
                  Navigator.pop(context);
                  // Pop the reset password dialog using the root navigator context
                  Navigator.of(context, rootNavigator: true).pop();
                  widget.onResetComplete(); // Navigate to login
                },
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        Navigator.pop(dialogContext); // Pop loading dialog
        setState(() {
          _error = 'Failed to reset password';
        });
      }
    } catch (e) {
      Logger.error('Error resetting password', e);
      if (!mounted) return;
      Navigator.pop(dialogContext); // Pop loading dialog
      setState(() {
        _error = 'An error occurred while resetting password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Reset Password',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Please enter your new password.',
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
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_outline),
                helperText:
                    'Must contain uppercase, lowercase, number, and special character',
              ),
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            // Password strength indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: _passwordStrength,
                  backgroundColor: AppColors.highlightOverlay,
                  valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Password strength: $_strengthText',
                  style: TextStyle(
                    color: _strengthColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _resetPassword(),
            ),
          ],
        ),
      ),
      actions: [
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
          onPressed: _resetPassword,
          child: const Text(
            'Reset Password',
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
