import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

class ForgotPINScreen extends StatefulWidget {
  const ForgotPINScreen({super.key});

  @override
  State<ForgotPINScreen> createState() => _ForgotPINScreenState();
}

class _ForgotPINScreenState extends State<ForgotPINScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _repository = AccountRepositoryImpl();
  final _securityService = SecurityService();
  final _databaseHelper = DatabaseHelper();
  
  bool _isLoading = false;
  bool _isVerified = false;
  bool _usesBiometric = false;
  String _errorMessage = '';
  String _pin = '';
  String _confirmPin = '';

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _loadSavedPhone();
  }

  Future<void> _checkBiometric() async {
    final usesBiometric = await _securityService.usesBiometric();
    if (mounted) {
      setState(() {
        _usesBiometric = usesBiometric;
      });
    }
  }

  Future<void> _loadSavedPhone() async {
    final user = await _databaseHelper.getUser();
    if (user != null && mounted) {
      final phoneNumber = user.phone.startsWith('+') 
          ? user.phone.substring(1) 
          : user.phone;
      setState(() {
        _phoneController.text = phoneNumber;
      });
    }
  }

  Future<void> _verifyWithBiometric() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final (authenticated, error) = await _securityService.authenticateWithBiometrics();
      
      if (authenticated) {
        setState(() {
          _isVerified = true;
        });
      } else {
        setState(() {
          _errorMessage = error ?? 'Biometric authentication failed';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyWithPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final phoneNumber = '+${_phoneController.text}';
      final result = await _repository.login(
        phone: phoneNumber,
        password: _passwordController.text,
      );

      result.fold(
        (failure) {
          setState(() {
            _errorMessage = 'Invalid credentials. Please try again.';
          });
        },
        (user) {
          setState(() {
            _isVerified = true;
          });
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePin() async {
    if (_pin.isEmpty || _confirmPin.isEmpty) return;
    
    if (_pin != _confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _pin = '';
        _confirmPin = '';
        _pinController.clear();
        _confirmPinController.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _securityService.setPin(_pin);
      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'PIN Reset Successful',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Your PIN has been successfully reset. You will now be redirected to the login screen.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  // Use pushNamedAndRemoveUntil to ensure clean navigation
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/auth',
                    (route) => false,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update PIN. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildVerificationSection() {
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
      prefixIconColor: AppColors.primary,
    );

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: const Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security,
                    color: AppColors.info,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verify Your Identity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'To reset your PIN, we need to verify your identity first.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (_usesBiometric) ...[
          FilledButton.icon(
            onPressed: _isLoading ? null : _verifyWithBiometric,
            icon: const Icon(Icons.fingerprint),
            label: const Text('Verify with Biometric'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(200, 50),
              disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'OR',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: inputDecorationTheme,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    enabled: !_isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _verifyWithPassword,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textPrimary,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
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
                        : const Text('Verify Identity'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinResetSection() {
    const TextStyle pinTextStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Identity Verified',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _pin.isEmpty
                    ? 'Enter your new PIN'
                    : 'Confirm your new PIN',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50),
          child: PinCodeTextField(
            appContext: context,
            length: 4,
            obscureText: true,
            animationType: AnimationType.fade,
            controller: _pin.isEmpty ? _pinController : _confirmPinController,
            keyboardType: TextInputType.number,
            textStyle: pinTextStyle,
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(8),
              fieldHeight: 50,
              fieldWidth: 40,
              activeFillColor: AppColors.surface,
              inactiveFillColor: AppColors.surface,
              selectedFillColor: AppColors.surface,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.primary.withOpacity(0.3),
              selectedColor: AppColors.primary,
              errorBorderColor: AppColors.error,
            ),
            cursorColor: AppColors.primary,
            animationDuration: const Duration(milliseconds: 300),
            enableActiveFill: true,
            onCompleted: (value) {
              setState(() {
                if (_pin.isEmpty) {
                  _pin = value;
                  _pinController.clear();
                } else {
                  _confirmPin = value;
                  _updatePin();
                }
              });
            },
            onChanged: (value) {},
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reset PIN'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_errorMessage.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _isVerified ? _buildPinResetSection() : _buildVerificationSection(),
          ],
        ),
      ),
    );
  }
}
