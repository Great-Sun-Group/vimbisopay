import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';

class SecuritySetupScreen extends StatefulWidget {
  final User user;
  
  const SecuritySetupScreen({
    super.key,
    required this.user,
  });

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  final SecurityService _securityService = SecurityService();
  final AccountRepositoryImpl _repository = AccountRepositoryImpl();
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  bool _isBiometricAvailable = false;
  String _pin = '';
  String _confirmPin = '';
  bool _isPinSetupMode = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    // Request focus for PIN field when entering PIN setup mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isPinSetupMode && mounted) {
        _pinFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Widget _buildSecurityInfoBanner() {
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
                Icons.security,
                color: AppColors.info,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enhanced Security Setup',
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
            'Add an extra layer of security to protect your account. This helps ensure only you can access your money and personal information.',
            style: TextStyle(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkBiometric() async {
    final isAvailable = await _securityService.isBiometricAvailable();
    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
      });
    }
  }

  Future<void> _saveUserAndNavigateHome() async {
    final result = await _repository.saveUser(widget.user);
    
    if (!mounted) return;

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

  Future<void> _setupBiometric() async {
    try {
      await _securityService.setBiometricEnabled();
      if (mounted) {
        await _saveUserAndNavigateHome();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _clearPin() {
    if (mounted && !_isDisposed) {
      setState(() {
        _pin = '';
        _confirmPin = '';
      });
      _pinController.clear();
      // Request focus back to first PIN cell
      _pinFocusNode.requestFocus();
    }
  }

  Future<void> _setupPin() async {
    if (_pin.isEmpty) {
      if (mounted && !_isDisposed) {
        setState(() {
          _isPinSetupMode = true;
        });
        // Request focus when entering PIN setup mode
        _pinFocusNode.requestFocus();
      }
      return;
    }

    if (_confirmPin.isEmpty) {
      if (_pin.length == 4) {
        if (mounted && !_isDisposed) {
          setState(() {
            _confirmPin = '';
          });
          _pinController.clear();
        }
      }
      return;
    }

    if (_pin == _confirmPin) {
      await _securityService.setPin(_pin);
      if (mounted) {
        await _saveUserAndNavigateHome();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PINs do not match. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        _clearPin();
      }
    }
  }

  Widget _buildPinSetup() {
    final isConfirming = _pin.isNotEmpty && _pin.length == 4;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.pin,
                    color: AppColors.warning,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isConfirming ? 'Confirm Your PIN' : 'Create Your PIN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isConfirming
                    ? 'Re-enter your PIN to confirm and complete the setup.'
                    : 'Choose a 4-digit PIN that you\'ll remember. This PIN will be used to access your account.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
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
            controller: _pinController,
            focusNode: _pinFocusNode,
            autoFocus: true,
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
            onCompleted: (value) {
              if (!mounted || _isDisposed) return;

              setState(() {
                if (_pin.isEmpty) {
                  _pin = value;
                  _pinController.clear();
                } else {
                  _confirmPin = value;
                  _setupPin();
                }
              });
            },
            onChanged: (_) {
              // Pin code changes are handled in onCompleted
            },
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () {
            if (mounted && !_isDisposed) {
              setState(() {
                _isPinSetupMode = false;
                _pin = '';
                _confirmPin = '';
              });
              _pinController.clear();
            }
          },
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          label: Text(
            'Choose Different Method',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityChoice() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSecurityInfoBanner(),
        const SizedBox(height: 32),
        if (_isBiometricAvailable) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.fingerprint,
                  size: 48,
                  color: AppColors.success,
                ),
                const SizedBox(height: 16),
                Text(
                  'Biometric Authentication',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use your fingerprint or face recognition for quick and secure access to your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _setupBiometric,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Use Biometric'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'OR',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
        ],
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.pin,
                size: 48,
                color: AppColors.warning,
              ),
              const SizedBox(height: 16),
              Text(
                'PIN Setup',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a 4-digit PIN to secure your account. Make sure to choose a PIN you\'ll remember.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.4,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _setupPin,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Set up PIN'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Security Setup'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: _isPinSetupMode ? _buildPinSetup() : _buildSecurityChoice(),
          ),
        ),
      ),
    );
  }
}
