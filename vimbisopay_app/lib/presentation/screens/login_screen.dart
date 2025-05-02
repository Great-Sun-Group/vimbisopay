import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/screens/forgot_pin_screen.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/phone_validator.dart';
import 'package:vimbisopay_app/core/utils/plain_phone_formatter.dart';
import 'package:vimbisopay_app/core/utils/screen_tracker.dart';
import 'package:vimbisopay_app/core/utils/button_tracker.dart';
import 'package:vimbisopay_app/core/theme/input_decoration_theme.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart' show LoadingDialog;
import 'dart:async' show unawaited;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with ScreenViewTrackerMixin {
  @override
  String get screenName => 'LoginScreen';
  
  @override
  Map<String, dynamic> get screenParameters => {};
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _repository = ServiceLocator.accountRepository;
  final _databaseHelper = ServiceLocator.databaseHelper;
  bool _isFormValid = false;
  bool _isLoading = false;
  final Map<String, String?> _fieldErrors = {
    'phone': null,
  };
  final Set<String> _touchedFields = {};

  void _markFieldAsTouched(String fieldName) {
    setState(() {
      _touchedFields.add(fieldName);
    });
  }

  String? _getFieldError(String fieldName) {
    // Only return non-empty error messages
    final error = _touchedFields.contains(fieldName) ? _fieldErrors[fieldName] : null;
    return (error != null && error.isNotEmpty) ? error : null;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedUser();
  }

  Future<void> _loadSavedUser() async {
    final user = await _databaseHelper.getUser();
    if (user != null && mounted) {
      // Remove any non-digit characters
      final phoneNumber = user.phone.replaceAll(RegExp(r'\D'), '');
      setState(() {
        _phoneController.text = phoneNumber;
      });
      _validateForm();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final phone = _phoneController.text;

    Logger.data('[Login] Validating form fields');
    
    setState(() {
      _fieldErrors['phone'] = PhoneValidator.validatePhone(phone);

      // Check if phone number is valid
      final hasValidPhone = phone.isNotEmpty && PhoneValidator.validatePhone(phone) == null;

      // Update form validity
      _isFormValid = hasValidPhone;
          
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
            'VimbisoPay',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Log in to grow your business and manage your wealth.',
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

  void _showErrorDialog(String message, {String title = 'Login Failed'}) {
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
                Text(
                  title,
                  style: const TextStyle(
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

  // _doV1Login method removed as we're no longer using passwords

  Future<void> _handleLogin() async {
    Logger.interaction('[Login] Login button pressed');
    
    // Track login button tap
    ButtonTracker.trackButtonTap(
      'login_button',
      screenName: screenName,
      parameters: {
        'phone_number_length': _phoneController.text.length,
      },
    );
    
    // Validate form first
    setState(() {
      _touchedFields.addAll(['phone']);
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


    // Show loading dialog
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.barrierColor,
      useSafeArea: false,
      routeSettings: const RouteSettings(name: 'loading_dialog'),
      builder: (context) {
        Logger.interaction('[Login] Building loading dialog');
        return const LoadingDialog(
          message: 'Logging you in...',
        );
      },
    ));

    // The phone number is already in the correct format (digits only)
    // thanks to PlainPhoneNumberFormatter
    final phoneNumber = _phoneController.text;
    
    Logger.interaction('[Login] Calling login API');
    Logger.performance('[Login] API call start: login');
    
    final result = await _repository.login(
      phone: phoneNumber,
    );

    if (!mounted) return;
    
    Logger.performance('[Login] API call complete: login');
    
    // Helper function to safely pop dialog and update state
    void cleanup() {
      if (mounted) {
        Navigator.of(context).pop(); // Pop loading dialog
        setState(() {
          _isLoading = false;
        });
      }
    }

    result.fold(
      (failure) async {
        Logger.error('[Login] Login failed', failure);
        cleanup();

        // Use the failure message if available, otherwise translate the error
        final errorMessage = failure.message ?? ErrorTranslator.translateError(failure);
        _showErrorDialog(errorMessage);
      },
      (user) async {
        Logger.interaction('[Login] Login successful');
        cleanup();
        
        // No OTP verification needed, proceed normally
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
                            helperText: 'Start with country code (e.g. 263 for Zimbabwe, 353 for Ireland, 1 for USA/Canada)',
                            helperMaxLines: 2,
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            PlainPhoneNumberFormatter(),
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
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).nextFocus();
                          },
                          validator: (_) => _getFieldError('phone'),
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
                                // Track forgot PIN button tap
                                ButtonTracker.trackButtonTap(
                                  'forgot_pin_button',
                                  screenName: screenName,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ForgotPINScreen(),
                                  ),
                                );
                              },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text(
                          'Forgot PIN?',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Register section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.highlightOverlay,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Not a Member Yet?',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      // Track register button tap
                                      ButtonTracker.trackButtonTap(
                                        'register_button',
                                        screenName: screenName,
                                      );
                                      Navigator.pushNamed(context, '/create-account');
                                    },
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: AppColors.surface,
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
