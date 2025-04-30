import 'package:flutter/material.dart';
import 'package:dartz/dartz.dart' show Either;
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/password_validator.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/success_dialog.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';

class ChangePasswordBottomSheet extends StatefulWidget {
  final String? resetToken;
  final String? memberId;

  const ChangePasswordBottomSheet({
    super.key,
    this.resetToken,
    this.memberId,
  });

  @override
  State<ChangePasswordBottomSheet> createState() => _ChangePasswordBottomSheetState();
}

class _ChangePasswordBottomSheetState extends State<ChangePasswordBottomSheet> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _repository = ServiceLocator.accountRepository;
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
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
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _changePassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validation
    if (widget.resetToken == null && _currentPasswordController.text.isEmpty) {
      setState(() => _error = 'Current password is required');
      return;
    }
    
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }

    if (!PasswordValidator.isValid(newPassword)) {
      setState(() => _error = 'Password must be at least 8 characters long and contain uppercase, lowercase, number, and special character');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _error = 'New passwords do not match');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final bool success;
      if (widget.resetToken != null) {
        success = await _repository.resetPassword(
          resetToken: widget.resetToken!, // Use the verification token
          newPassword: newPassword,
        );
      } else {
        final result = await _repository.updatePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: newPassword,
        );
        success = result.fold(
          (failure) {
            setState(() {
              _error = failure.message ?? ErrorTranslator.translateError(failure);
              _isLoading = false;
            });
            return false;
          },
          (_) => true,
        );
      }

      if (!mounted) return;

      if (success) {
        // Close bottom sheet first
        Navigator.of(context).pop();
        
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => SuccessDialog(
            title: 'Password Reset Successful',
            message: 'Your password has been successfully reset. Please log in with your new password.',
            onDismiss: () {
              // Navigate to auth screen and clear stack
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/auth',
                (route) => false,
              );
            },
          ),
        );
      } else {
        setState(() {
          _error = ErrorTranslator.getGenericErrorMessage();
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Error changing password', e);
      if (mounted) {
        setState(() {
          _error = ErrorTranslator.translateError(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Change Password',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (_isLoading)
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                SizedBox(height: 16),
                Text(
                  'Changing password...',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
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
                if (widget.resetToken == null) TextField(
                  controller: _currentPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isCurrentPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _isCurrentPasswordVisible = !_isCurrentPasswordVisible),
                    ),
                  ),
                  obscureText: !_isCurrentPasswordVisible,
                  textInputAction: TextInputAction.next,
                ),
                if (widget.resetToken == null) const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _newPasswordController,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        helperText: '',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isNewPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
                        ),
                      ),
                      obscureText: !_isNewPasswordVisible,
                      textInputAction: TextInputAction.next,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Password must contain:',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '• At least 8 characters',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '• Uppercase letter',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '• Lowercase letter',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '• Number',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '• Special character',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
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
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                    ),
                  ),
                  obscureText: !_isConfirmPasswordVisible,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _changePassword(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Change Password',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
