import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/screens/forgot_password_screen.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/password_validator.dart';
import 'package:vimbisopay_app/core/utils/phone_validator.dart';
import 'package:vimbisopay_app/core/utils/phone_formatter.dart';
import 'package:vimbisopay_app/core/theme/input_decoration_theme.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart' show LoadingDialog;
import 'dart:async' show unawaited;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repository = AccountRepositoryImpl();
  final _databaseHelper = DatabaseHelper();
  bool _isFormValid = false;
  bool _isLoading = false;
  bool _showPassword = false;
  Map<String, String?> _fieldErrors = {
    'phone': null,
    'password': null,
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
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
    _loadSavedUser();
  }

  Future<void> _loadSavedUser() async {
    final user = await _databaseHelper.getUser();
    if (user != null && mounted) {
      // Remove the '+' prefix if it exists
      final phoneNumber = user.phone.startsWith('+') 
          ? user.phone.substring(1) 
          : user.phone;
      setState(() {
        _phoneController.text = phoneNumber;
      });
      _validateForm();
    }
  }

  @override
  void dispose() {
    if (!_isLoading) {
      _spinController.dispose();
    }
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final phone = _phoneController.text;
    final password = _passwordController.text;

    Logger.data('[Login] Validating form fields');
    
    setState(() {
      _fieldErrors['phone'] = PhoneValidator.validatePhone(phone);

      final passwordValidation = PasswordValidator.validatePassword(password);
      _fieldErrors['password'] = passwordValidation.error;

      // Check if all required fields have valid values
      final hasValidPhone = phone.isNotEmpty && PhoneValidator.validatePhone(phone) == null;
      final hasValidPassword = PasswordValidator.validatePassword(password).isValid;

      // Update form validity
      _isFormValid = hasValidPhone && hasValidPassword;
          
      Logger.data('[Login] Form validation result: ${_isFormValid ? 'valid' : 'invalid'}');
      if (!_isFormValid) {
        Logger.data('[Login] Invalid fields: ${_fieldErrors.entries.where((e) => e.value != null).map((e) => e.key).join(', ')}');
      }
    });
  }

  Widget _buildWelcomeBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 48,
            color: AppColors.primary,
          ),
          SizedBox(height: 16),
          Text(
            'Welcome Back!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Log in to your VimbisoPay account to send money, check balances, and manage your transactions securely.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfoBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.info.withOpacity(0.2),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.security_outlined,
            color: AppColors.info,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your security is our priority. We use industry-standard encryption to protect your information.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: AppColors.error,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Login Failed',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleLogin() async {
    Logger.interaction('[Login] Login button pressed');
    
    // Validate form first
    setState(() {
      _touchedFields.addAll(['phone', 'password']);
    });
    
    _validateForm();
    _formKey.currentState!.validate();
    
    if (!_isFormValid) {
      Logger.data('[Login] Form validation failed, aborting login');
      return;
    }
    
    // Dismiss keyboard before showing dialog
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isLoading = true;
    });

    _spinController.repeat();

    // Show loading dialog
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      useSafeArea: false,
      routeSettings: const RouteSettings(name: 'loading_dialog'),
      builder: (context) {
        Logger.interaction('[Login] Building loading dialog');
        return LoadingDialog(
          spinController: _spinController,
          message: 'Logging you in...',
        );
      },
    ));

    final phoneNumber = '+${_phoneController.text}';
    final password = _passwordController.text;
    
    Logger.interaction('[Login] Calling login API');
    Logger.performance('[Login] API call start: login');
    
    final result = await _repository.login(
      phone: phoneNumber,
      password: password,
    );

    if (!mounted) return;
    
    Logger.performance('[Login] API call complete: login');
    
    // Helper function to safely pop dialog and update state
    void cleanup() {
      if (mounted) {
        Navigator.of(context).pop(); // Pop loading dialog
        setState(() {
          _isLoading = false;
          _spinController.stop();
        });
      }
    }

    result.fold(
      (failure) async {
        Logger.error('[Login] Login failed', failure);
        cleanup();
        _showErrorDialog(
          'We couldn\'t log you in. Please check your phone number and password, then try again.',
        );
      },
      (user) async {
        Logger.interaction('[Login] Login successful');
        Logger.interaction('[Login] Saving user data');
        await _databaseHelper.saveUser(user);
        
        if (mounted) {
          Logger.interaction('[Login] Navigating to auth screen');
          Navigator.pushReplacementNamed(
            context,
            '/auth',
            arguments: user,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              _buildWelcomeBanner(),
              _buildSecurityInfoBanner(),
              Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: inputDecorationTheme,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
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
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isFormValid && !_isLoading ? _handleLogin : null,
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
                                'Login',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isLoading 
                            ? null 
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
