import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/password_validator.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  late final StreamController<String> _messageController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _repository = ServiceLocator.accountRepository;
  String? _error;
  double _passwordStrength = 0.0;
  String _strengthText = 'Too weak';
  Color _strengthColor = AppColors.error;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_updatePasswordStrength);
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
    _messageController = StreamController<String>.broadcast();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _spinController.dispose();
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

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validation
    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
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
      setState(() => _error = null);

      // Start spinner and show loading dialog
      _spinController.repeat();
      final dialogContext = context;
      showDialog(
        context: dialogContext,
        barrierDismissible: false,
        builder: (context) => LoadingDialog(
          spinController: _spinController,
          message: 'Updating password...',
          messageStream: _messageController.stream,
        ),
      );

      // Update message during API call
      _messageController.add('Verifying current password...');
      await Future.delayed(const Duration(milliseconds: 300));
      
      final result = await _repository.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!mounted) return;

      result.fold(
        (failure) {
          Navigator.pop(dialogContext); // Pop loading dialog
          _spinController.stop();
          setState(() => _error = failure.message ?? 'Failed to change password');
        },
        (_) {
          Navigator.pop(dialogContext); // Pop loading dialog
          Navigator.pop(context, true); // Pop password dialog
        },
      );
    } catch (e) {
      Logger.error('Error changing password', e);
      if (mounted) {
        setState(() => _error = 'Failed to change password. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Change Password',
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
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showCurrentPassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                ),
              ),
              obscureText: !_showCurrentPassword,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                helperText: 'Must contain uppercase, lowercase, number, and special character',
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNewPassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                ),
              ),
              obscureText: !_showNewPassword,
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
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                ),
              ),
              obscureText: !_showConfirmPassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _changePassword(),
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
          onPressed: _changePassword,
          child: const Text(
            'Change Password',
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
