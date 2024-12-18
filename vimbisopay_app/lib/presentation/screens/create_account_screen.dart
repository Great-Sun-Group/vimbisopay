import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _repository = AccountRepositoryImpl();
  bool _isFormValid = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _firstNameController.text.isNotEmpty &&
                     _lastNameController.text.isNotEmpty &&
                     _phoneController.text.isNotEmpty && 
                     _passwordController.text.isNotEmpty &&
                     _confirmPasswordController.text.isNotEmpty &&
                     _passwordController.text == _confirmPasswordController.text &&
                     _passwordController.text.length >= 6;
    });
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (!RegExp(r'^[0-9]{3}[0-9]+$').hasMatch(value)) {
      return 'Start with country code (e.g. 263 or 353)';
    }
    if (value.length < 10) {
      return 'Phone number is too short';
    }
    return null;
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Error',
            style: TextStyle(color: AppColors.error),
          ),
          content: Text(
            message,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCreateAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        },
      );

      if (!mounted) return;

      final phoneNumber = '+${_phoneController.text}';
      final password = _passwordController.text;
      
      final result = await _repository.onboardMember(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: phoneNumber,
        password: password,
      );

      if (mounted) {
        Navigator.pop(context); // Remove loading dialog

        result.fold(
          (failure) {
            _showError(failure.message ?? 'Failed to create account');
          },
          (success) async {
            if (success) {
              Logger.interaction('Account created successfully, attempting login');
              // After successful onboarding, attempt login
              final loginResult = await _repository.login(
                phone: phoneNumber,
                password: password,
              );

              loginResult.fold(
                (failure) {
                  Logger.error('Failed to login after account creation', failure);
                  _showError('Account created but login failed. Please try logging in manually.');
                },
                (user) {
                  Logger.interaction('Login successful, navigating to security setup');
                  Navigator.pushReplacementNamed(
                    context,
                    '/security-setup',
                    arguments: user,
                  );
                },
              );
            } else {
              _showError('Failed to create account. Please try again.');
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading dialog
        _showError('An unexpected error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
    );

    final inputDecorationTheme = InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      helperStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
      errorStyle: const TextStyle(color: AppColors.error),
      prefixIconColor: AppColors.primary,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: inputDecorationTheme,
            ),
            child: Form(
              key: _formKey,
              onChanged: _validateForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome to VimbisoPay!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your account to start sending and receiving money securely.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your first name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your last name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                      hintText: '263712345678 or 353871234567',
                      helperText: 'Start with country code (e.g. 263 for Zimbabwe, 353 for Ireland)',
                      helperMaxLines: 2,
                    ),
                    keyboardType: TextInputType.phone,
                    enabled: !_isLoading,
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      helperText: 'At least 6 characters',
                    ),
                    obscureText: true,
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      helperText: 'Re-enter your password',
                    ),
                    obscureText: true,
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isFormValid && !_isLoading ? _handleCreateAccount : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textPrimary,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
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
                            'Create Account',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
