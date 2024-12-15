import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../infrastructure/services/security_service.dart';
import '../../infrastructure/repositories/account_repository_impl.dart';
import '../../infrastructure/database/database_helper.dart';
import '../../domain/entities/user.dart';
import '../../core/theme/app_colors.dart';
import 'security_setup_screen.dart';
import 'login_screen.dart';
import 'forgot_pin_screen.dart';

class AuthScreen extends StatefulWidget {
  final User? user;
  
  const AuthScreen({
    super.key,
    this.user,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final SecurityService _securityService = SecurityService();
  final AccountRepositoryImpl _repository = AccountRepositoryImpl();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late final FocusNode _pinFocusNode;
  String _pin = '';
  bool _isLoading = true;
  bool _usesBiometric = false;
  User? _user;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _pinFocusNode = FocusNode();
    _initialize();
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (mounted) {
      _pinFocusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    _user = widget.user;
    if (_user == null) {
      _user = await _databaseHelper.getUser();
      if (_user == null && mounted && !_isDisposed) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        return;
      }
    }
    _checkSecuritySetup();
  }

  Future<void> _checkSecuritySetup() async {
    final isSetup = await _securityService.isSecuritySetup();
    if (!isSetup) {
      if (mounted && !_isDisposed && _user != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => SecuritySetupScreen(user: _user!),
          ),
          (route) => false,
        );
        return;
      }
    }

    final usesBiometric = await _securityService.usesBiometric();
    if (mounted && !_isDisposed) {
      setState(() {
        _usesBiometric = usesBiometric;
        _isLoading = false;
      });

      if (_usesBiometric) {
        _authenticateWithBiometric();
      } else {
        // Only request focus if the widget is still mounted and not disposed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposed) {
            _pinFocusNode.requestFocus();
          }
        });
      }
    }
  }

  Widget _buildAuthBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _usesBiometric ? Icons.fingerprint : Icons.lock,
                color: AppColors.info,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _usesBiometric ? 'Biometric Authentication' : 'PIN Authentication',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _usesBiometric
                ? 'Use your fingerprint or face recognition to securely access your account.'
                : 'Enter your 4-digit PIN to securely access your account.',
            style: TextStyle(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityReminder() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Never share your PIN or allow biometric access to anyone else.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUserAndNavigateHome() async {
    if (_user == null) return;
    
    final result = await _repository.saveUser(_user!);
    
    if (!mounted || _isDisposed) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save user data: ${failure.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      },
      (_) => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
    );
  }

  Future<void> _authenticateWithBiometric() async {
    final (authenticated, errorMessage) = await _securityService.authenticateWithBiometrics();
    
    if (!mounted || _isDisposed) return;

    if (authenticated) {
      await _saveUserAndNavigateHome();
    } else if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Use PIN',
            onPressed: () {
              if (mounted && !_isDisposed) {
                setState(() {
                  _usesBiometric = false;
                });
                // Only request focus if the widget is still mounted and not disposed
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_isDisposed) {
                    _pinFocusNode.requestFocus();
                  }
                });
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _verifyPin(String pin) async {
    final isValid = await _securityService.verifyPin(pin);
    if (isValid && mounted && !_isDisposed) {
      await _saveUserAndNavigateHome();
    } else if (mounted && !_isDisposed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid PIN. Please try again.'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        _pin = '';
      });
      // Only request focus if the widget is still mounted and not disposed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          _pinFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Authentication Required'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            _buildAuthBanner(),
            if (_usesBiometric) ...[
              Icon(
                Icons.fingerprint,
                size: 72,
                color: AppColors.info,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _authenticateWithBiometric,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Authenticate with Biometric'),
              ),
              TextButton(
                onPressed: () {
                  if (mounted && !_isDisposed) {
                    setState(() {
                      _usesBiometric = false;
                    });
                    // Only request focus if the widget is still mounted and not disposed
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_isDisposed) {
                        _pinFocusNode.requestFocus();
                      }
                    });
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('Use PIN Instead'),
              ),
            ] else ...[
              Text(
                'Enter PIN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: PinCodeTextField(
                  appContext: context,
                  length: 4,
                  obscureText: true,
                  animationType: AnimationType.fade,
                  focusNode: _pinFocusNode,
                  keyboardType: TextInputType.number,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(5),
                    fieldHeight: 50,
                    fieldWidth: 40,
                    activeFillColor: AppColors.surface,
                    inactiveFillColor: AppColors.surface,
                    selectedFillColor: AppColors.surface,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.textSecondary.withOpacity(0.3),
                    selectedColor: AppColors.primary,
                  ),
                  animationDuration: const Duration(milliseconds: 300),
                  enableActiveFill: true,
                  onCompleted: _verifyPin,
                  onChanged: (value) {
                    if (mounted && !_isDisposed) {
                      setState(() {
                        _pin = value;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (_usesBiometric)
                TextButton(
                  onPressed: () {
                    if (mounted && !_isDisposed) {
                      setState(() {
                        _usesBiometric = true;
                      });
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Text('Use Biometric Instead'),
                ),
              TextButton(
                onPressed: () {
                  if (mounted && !_isDisposed) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPINScreen(),
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('Forgot PIN?'),
              ),
            ],
            _buildSecurityReminder(),
          ],
        ),
      ),
    );
  }
}
