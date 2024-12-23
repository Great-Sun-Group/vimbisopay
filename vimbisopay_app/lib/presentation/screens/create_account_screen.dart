import 'dart:async' show Future, StreamController, StreamSubscription, unawaited;
import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/password_validator.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';

import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart' show LoadingDialog;
import 'package:vimbisopay_app/core/utils/phone_validator.dart';
import 'package:vimbisopay_app/core/utils/phone_formatter.dart';
import 'package:vimbisopay_app/core/theme/input_decoration_theme.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
  }

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
  final Map<String, String?> _fieldErrors = {
    'firstName': null,
    'lastName': null,
    'phone': null,
    'password': null,
    'confirmPassword': null,
  };
  
  final Set<String> _touchedFields = {};

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
    // Only dispose the spin controller if we're not in the middle of account creation
    if (!_isLoading) {
      _spinController.dispose();
    }
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

    Logger.data('[CreateAccount] Validating form fields');
    
    setState(() {
      // Show validation errors immediately
      _fieldErrors['firstName'] = firstName.isEmpty ? 'Please enter your first name' : null;
      _fieldErrors['lastName'] = lastName.isEmpty ? 'Please enter your last name' : null;
      _fieldErrors['phone'] = PhoneValidator.validatePhone(phone);

      final passwordValidation = PasswordValidator.validatePassword(password);
      _fieldErrors['password'] = passwordValidation.error;

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
      final hasValidPhone = phone.isNotEmpty && PhoneValidator.validatePhone(phone) == null;
      final hasValidPassword = PasswordValidator.validatePassword(password).isValid;
      final hasValidConfirmPassword = confirmPassword.isNotEmpty && confirmPassword == password;

      // Update form validity
      _isFormValid = hasValidFirstName &&
          hasValidLastName &&
          hasValidPhone &&
          hasValidPassword &&
          hasValidConfirmPassword &&
          _acceptedTerms;
          
      Logger.data('[CreateAccount] Form validation result: ${_isFormValid ? 'valid' : 'invalid'}');
      if (!_isFormValid) {
        Logger.data('[CreateAccount] Invalid fields: ${_fieldErrors.entries.where((e) => e.value != null).map((e) => e.key).join(', ')}');
      }
    });
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
    Logger.interaction('[CreateAccount] Create account button pressed');
    
    // Validate form first
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
    
    if (!_isFormValid) {
      Logger.data('[CreateAccount] Form validation failed, aborting account creation');
      return;
    }

    // Dismiss keyboard before showing dialog for smoother animation
    FocusScope.of(context).unfocus();
    
    // Show loading dialog immediately after validation passes
    if (!mounted) return;
    
    Logger.interaction('[CreateAccount] About to show loading dialog');
    
    // Use a state variable to track if dialog is showing
    setState(() {
      _isLoading = true;
    });

    _spinController.repeat();
    
    Logger.interaction('[CreateAccount] Set loading state to true');
    
    // Helper function to safely pop dialog and update state
    void popDialog() {
      if (mounted && _isLoading) {
        Logger.interaction('[CreateAccount] Popping dialog');
        Navigator.pop(context);
        setState(() {
          _isLoading = false;
        });
      }
    }

    late final messageController = StreamController<String>.broadcast(
      onCancel: () => Logger.interaction('[CreateAccount] Message stream cancelled'),
      onListen: () => Logger.interaction('[CreateAccount] Message stream has listener'),
    );
    
    void cleanup() {
      Logger.interaction('[CreateAccount] Cleaning up dialog');
      if (!messageController.isClosed) {
        Logger.interaction('[CreateAccount] Closing message stream');
        messageController.close();
      }
      if (mounted) {
        Navigator.of(context).pop();
        setState(() {
          _isLoading = false;
          _spinController.stop();
        });
      }
    }
    
    try {
      final phoneNumber = '+${_phoneController.text}';
      final password = _passwordController.text;
      
      Logger.interaction('[CreateAccount] Starting account creation process');
      Logger.data('[CreateAccount] Preparing request - ' 
          'firstName: ${_firstNameController.text}, '
          'lastName: ${_lastNameController.text}, '
          'phone: $phoneNumber');

      // Show loading dialog and keep it open while we update messages
      unawaited(showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black26,
        useSafeArea: false,
        routeSettings: const RouteSettings(name: 'loading_dialog'),
        builder: (context) {
          Logger.interaction('[CreateAccount] Building loading dialog');
          return LoadingDialog(
            spinController: _spinController,
            message: 'Creating your account...',
            messageStream: messageController.stream,
          );
        },
      ));

      // Small delay to ensure dialog is mounted
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) {
        Logger.interaction('[CreateAccount] Widget not mounted after dialog, cleaning up');
        cleanup();
        return;
      }

      Logger.interaction('[CreateAccount] Widget still mounted after dialog');
      // Update to account creation message
      Logger.interaction('[CreateAccount] Updating to account creation message');
      messageController.add('Creating your account...');
      await Future.delayed(const Duration(milliseconds: 300));
      
      Logger.interaction('[CreateAccount] Calling onboardMember API');
      Logger.performance('[CreateAccount] API call start: onboardMember');
      
      final result = await _repository.onboardMember(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: phoneNumber,
        password: password,
      );

      if (!mounted) return;
      
      Logger.performance('[CreateAccount] API call complete: onboardMember');
      result.fold(
        (failure) {
          cleanup();
          _showError(failure.message ?? 'Failed to create account');
        },
        (success) async {
          if (!success) {
            Logger.error('[CreateAccount] Account creation failed with success=false');
            cleanup();
            _showError('Failed to create account. Please try again.');
            return;
          }

          Logger.interaction('[CreateAccount] Account created successfully');
          Logger.interaction('[CreateAccount] Attempting login');
          
          if (!mounted) {
            cleanup();
            return;
          }

          // Update to login message with fade
          Logger.interaction('[CreateAccount] Updating to login message');
          messageController.add('Logging you in...');
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Attempt login
          Logger.interaction('[CreateAccount] Calling login API');
          Logger.performance('[CreateAccount] API call start: login');
          
          final loginResult = await _repository.login(
            phone: phoneNumber,
            password: password,
          );

          if (!mounted) return;

          Logger.performance('[CreateAccount] API call complete: login');
          loginResult.fold(
            (failure) async {
              Logger.error('[CreateAccount] Login failed after account creation', failure);
              await Future.delayed(const Duration(milliseconds: 300));
              cleanup();
              _showError('Account created but login failed. Please try logging in manually.');
            },
            (user) async {
              Logger.interaction('[CreateAccount] Login successful');
              Logger.interaction('[CreateAccount] Navigating to security setup');
              await Future.delayed(const Duration(milliseconds: 300));
              cleanup();
              
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/security-setup',
                  (route) => false,
                  arguments: user,
                );
              }
            },
          );
        },
      );
    } catch (e) {
      Logger.error('[CreateAccount] Unexpected error during account creation', e);
      if (mounted) {
        cleanup();
        _showError('An unexpected error occurred. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {

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
                            inputFormatters: [
                              PhoneNumberFormatter(),
                            ],
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
                              helperText: PasswordValidator.getRequirementsText(),
                              helperMaxLines: 6,
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
