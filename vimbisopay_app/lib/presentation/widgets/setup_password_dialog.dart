import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/password_validator.dart';
import 'package:vimbisopay_app/infrastructure/services/password_service.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';

class SetupPasswordDialog extends StatefulWidget {
  const SetupPasswordDialog({super.key});

  @override
  State<SetupPasswordDialog> createState() => _SetupPasswordDialogState();
}

class _SetupPasswordDialogState extends State<SetupPasswordDialog> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false; // Keep this for future implementation
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

  Future<void> _setupPassword() async {
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

    // Show loading state
    setState(() {
      _isLoading = true;
    });

    try {
      final repository = AccountRepositoryImpl();
      final result = await repository.setInitialPassword(
        password: newPassword,
      );

      if (!mounted) return;

      result.fold(
        (failure) {
          setState(() {
            _error = failure.message ?? 'Failed to set up password';
            _isLoading = false;
          });
        },
        (user) async {
          // Save updated user to database
          final databaseHelper = DatabaseHelper();
          await databaseHelper.saveUser(user);
          
          if (!mounted) return;
          
          // Close dialog and navigate to auth screen
          Navigator.pushReplacementNamed(
            context,
            '/auth',
            arguments: user,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An error occurred: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Set Up Password',
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
                  'Setting up password...',
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
                    'Please set up a password for your account to continue.',
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
                      helperText: 'Must contain uppercase, lowercase, number, and special character',
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
                    onSubmitted: (_) => _setupPassword(),
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
                  'Later',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _setupPassword,
                child: const Text(
                  'Set Password',
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
