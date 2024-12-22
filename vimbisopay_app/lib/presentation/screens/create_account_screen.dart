import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
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
  bool _acceptedTerms = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  Map<String, String?> _fieldErrors = {
    'firstName': null,
    'lastName': null,
    'phone': null,
    'password': null,
    'confirmPassword': null,
  };
  
  Set<String> _touchedFields = {};

  void _markFieldAsTouched(String fieldName) {
    setState(() {
      _touchedFields.add(fieldName);
    });
  }

  String? _getFieldError(String fieldName) {
    return _touchedFields.contains(fieldName) ? _fieldErrors[fieldName] : null;
  }

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
    final firstName = _firstNameController.text;
    final lastName = _lastNameController.text;
    final phone = _phoneController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      // Show validation errors immediately
      _fieldErrors['firstName'] = firstName.isEmpty ? 'Please enter your first name' : null;
      _fieldErrors['lastName'] = lastName.isEmpty ? 'Please enter your last name' : null;
      _fieldErrors['phone'] = _validatePhone(phone);

      if (password.isEmpty) {
        _fieldErrors['password'] = 'Please enter a password';
      } else if (password.length < 6) {
        _fieldErrors['password'] = 'Password must be at least 6 characters';
      } else {
        _fieldErrors['password'] = null;
      }

      if (confirmPassword.isEmpty) {
        _fieldErrors['confirmPassword'] = 'Please confirm your password';
      } else if (confirmPassword != password) {
        _fieldErrors['confirmPassword'] = 'Passwords do not match';
      } else {
        _fieldErrors['confirmPassword'] = null;
      }

      // Check if all required fields have valid values
      final hasValidFirstName = firstName.isNotEmpty;
      final hasValidLastName = lastName.isNotEmpty;
      final hasValidPhone = phone.isNotEmpty && _validatePhone(phone) == null;
      final hasValidPassword = password.isNotEmpty && password.length >= 6;
      final hasValidConfirmPassword = confirmPassword.isNotEmpty && confirmPassword == password;

      // Update form validity
      _isFormValid = hasValidFirstName &&
          hasValidLastName &&
          hasValidPhone &&
          hasValidPassword &&
          hasValidConfirmPassword &&
          _acceptedTerms;
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
    // Mark all fields as touched when attempting to create account
    setState(() {
      _touchedFields.addAll([
        'firstName',
        'lastName',
        'phone',
        'password',
        'confirmPassword'
      ]);
    });
    
    _validateForm();
    _formKey.currentState!.validate();
    if (!_isFormValid) return;

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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: inputDecorationTheme,
                  ),
                  child: Form(
                    key: _formKey,
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
                        Semantics(
                          label: 'First name input field',
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            enabled: !_isLoading,
                            onTap: () => _markFieldAsTouched('firstName'),
                            onChanged: (_) {
                              setState(() {
                                _validateForm();
                                _formKey.currentState?.validate();
                              });
                            },
                            onEditingComplete: () {
                              _markFieldAsTouched('firstName');
                              setState(() {
                                _validateForm();
                                _formKey.currentState?.validate();
                              });
                            },
                            validator: (_) => _getFieldError('firstName'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: 'Last name input field',
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            enabled: !_isLoading,
                            onTap: () => _markFieldAsTouched('lastName'),
                            onChanged: (_) {
                              setState(() {
                                _validateForm();
                                _formKey.currentState?.validate();
                              });
                            },
                            onEditingComplete: () {
                              _markFieldAsTouched('lastName');
                              setState(() {
                                _validateForm();
                                _formKey.currentState?.validate();
                              });
                            },
                            validator: (_) => _getFieldError('lastName'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: 'Phone number input field',
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone),
                              helperText: 'Start with country code (e.g. 263 for Zimbabwe, 353 for Ireland)',
                              helperMaxLines: 2,
                            ),
                            keyboardType: TextInputType.phone,
                            enabled: !_isLoading,
                            onTap: () => _markFieldAsTouched('phone'),
                            onChanged: (_) {
                              setState(() {
                                _validateForm();
                                _formKey.currentState?.validate();
                              });
                            },
                            onEditingComplete: () {
                              _markFieldAsTouched('phone');
                              setState(() {
                                _validateForm();
                                _formKey.currentState?.validate();
                              });
                            },
                            validator: (_) => _getFieldError('phone'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: 'Password input field',
                          child: TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              helperText: 'At least 6 characters',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                                tooltip: _showPassword ? 'Hide password' : 'Show password',
                              ),
                            ),
                            obscureText: !_showPassword,
                            enabled: !_isLoading,
                            onTap: () => _markFieldAsTouched('password'),
                            onChanged: (_) {
                              setState(() {
                                _validateForm();
                                _formKey.currentState?.validate();
                              });
                            },
                            onEditingComplete: () {
                              _markFieldAsTouched('password');
                              setState(() {
                                _validateForm();
                                _formKey.currentState?.validate();
                              });
                            },
                            validator: (_) => _getFieldError('password'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: 'Confirm password input field',
                          child: TextFormField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              helperText: 'Re-enter your password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showConfirmPassword = !_showConfirmPassword;
                                  });
                                },
                                tooltip: _showConfirmPassword ? 'Hide password' : 'Show password',
                              ),
                            ),
                            obscureText: !_showConfirmPassword,
                            enabled: !_isLoading,
                            onTap: () => _markFieldAsTouched('confirmPassword'),
                            onChanged: (_) {
                              setState(() {
                                _validateForm();
                                _formKey.currentState?.validate();
                              });
                            },
                            onEditingComplete: () {
                              _markFieldAsTouched('confirmPassword');
                              setState(() {
                                _validateForm();
                                _formKey.currentState?.validate();
                              });
                            },
                            validator: (_) => _getFieldError('confirmPassword'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Checkbox(
                              value: _acceptedTerms,
                              onChanged: (value) {
                                setState(() {
                                  _acceptedTerms = value ?? false;
                                  _validateForm();
                                });
                              },
                              activeColor: AppColors.primary,
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _acceptedTerms = !_acceptedTerms;
                                    _validateForm();
                                  });
                                },
                                child: const Text.rich(
                                  TextSpan(
                                    text: 'I agree to the ',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Terms and Conditions',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: FilledButton(
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
            ),
          ],
        ),
      ),
    );
  }
}
