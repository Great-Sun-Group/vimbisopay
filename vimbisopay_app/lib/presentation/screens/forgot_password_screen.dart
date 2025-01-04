import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/phone_validator.dart';
import 'package:vimbisopay_app/core/utils/phone_formatter.dart';
import 'package:vimbisopay_app/core/theme/input_decoration_theme.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart' show LoadingDialog;
import 'dart:async' show unawaited;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isFormValid = false;
  bool _isLoading = false;
  bool _isSubmitted = false;
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
    Logger.lifecycle('ForgotPasswordScreen initialized');
  }

  @override
  void dispose() {
    Logger.lifecycle('ForgotPasswordScreen disposing');
    if (!_isLoading) {
      _spinController.dispose();
    }
    _phoneController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final phone = _phoneController.text;

    Logger.data('[ForgotPassword] Validating form fields');
    
    setState(() {
      _fieldErrors['phone'] = PhoneValidator.validatePhone(phone);

      // Check if all required fields have valid values
      final hasValidPhone = phone.isNotEmpty && PhoneValidator.validatePhone(phone) == null;

      // Update form validity
      _isFormValid = hasValidPhone;
          
      Logger.data('[ForgotPassword] Form validation result: ${_isFormValid ? 'valid' : 'invalid'}');
      if (!_isFormValid) {
        Logger.data('[ForgotPassword] Invalid fields: ${_fieldErrors.entries.where((e) => e.value != null).map((e) => e.key).join(', ')}');
      }
    });
  }

  Widget _buildHeaderBanner() {
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
            Icons.lock_reset,
            size: 48,
            color: AppColors.primary,
          ),
          SizedBox(height: 16),
          Text(
            'Reset Password',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Enter your phone number and we\'ll send you instructions to reset your password.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildHeaderBanner(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.success.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Instructions Sent!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We\'ve sent password reset instructions to +${_phoneController.text}',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FilledButton(
            onPressed: () {
              Logger.interaction('Returning to login from forgot password success');
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Return to Login',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
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

  Future<void> _handleSubmit() async {
    Logger.interaction('[ForgotPassword] Submit button pressed');
    
    // Validate form first
    setState(() {
      _touchedFields.add('phone');
    });
    
    _validateForm();
    _formKey.currentState!.validate();
    
    if (!_isFormValid) {
      Logger.data('[ForgotPassword] Form validation failed, aborting submission');
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
        Logger.interaction('[ForgotPassword] Building loading dialog');
        return LoadingDialog(
          spinController: _spinController,
          message: 'Sending instructions...',
        );
      },
    ));

    try {
      // TODO: Implement actual password reset API call
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      Logger.interaction('[ForgotPassword] Instructions sent successfully');
      
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

      cleanup();
      setState(() {
        _isSubmitted = true;
      });
    } catch (e) {
      Logger.error('[ForgotPassword] Error sending reset instructions', e);
      if (mounted) {
        Navigator.of(context).pop(); // Pop loading dialog
        setState(() {
          _isLoading = false;
          _spinController.stop();
        });
        _showError('Failed to send reset instructions. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            child: _buildSuccessContent(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () {
            Logger.interaction('Returning to login from forgot password');
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderBanner(),
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
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isFormValid && !_isLoading ? _handleSubmit : null,
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
                                'Send Instructions',
                                style: TextStyle(fontSize: 16),
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
