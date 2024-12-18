import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/presentation/screens/forgot_pin_screen.dart';

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
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late final FocusNode _pinFocusNode;
  String _pin = '';
  bool _isLoading = true;
  bool _usesBiometric = false;
  User? _user;
  bool _isDisposed = false;
  bool _isAuthenticating = false;
  bool _biometricFailed = false;

  @override
  void initState() {
    super.initState();
    Logger.lifecycle('AuthScreen - Initializing');
    _pinFocusNode = FocusNode();
    _initialize();
  }

  @override
  void dispose() {
    Logger.lifecycle('AuthScreen - Disposing');
    _isDisposed = true;
    if (mounted) {
      _pinFocusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    Logger.lifecycle('AuthScreen - Starting initialization');
    try {
      _user = widget.user;
      Logger.state('AuthScreen - Initial user state: ${_user != null ? 'provided' : 'not provided'}');
      
      if (_user == null) {
        Logger.data('AuthScreen - Fetching user from database');
        _user = await _databaseHelper.getUser();
        Logger.state('AuthScreen - Database user state: ${_user != null ? 'found' : 'not found'}');
        
        if (_user == null && mounted && !_isDisposed) {
          Logger.state('AuthScreen - No user found, redirecting to login');
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }
      }
      
      await _checkSecuritySetup();
    } catch (e, stack) {
      Logger.error('AuthScreen - Error during initialization', e, stack);
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkSecuritySetup() async {
    Logger.state('AuthScreen - Checking security setup');
    try {
      final isSetup = await _securityService.isSecuritySetup();
      Logger.state('AuthScreen - Security setup status: $isSetup');
      
      if (!isSetup) {
        if (mounted && !_isDisposed && _user != null) {
          Logger.state('AuthScreen - Security not setup, redirecting to setup');
          Navigator.pushReplacementNamed(
            context,
            '/security-setup',
            arguments: _user,
          );
          return;
        }
      }

      final usesBiometric = await _securityService.usesBiometric();
      Logger.state('AuthScreen - Biometric status: $usesBiometric');
      
      if (mounted && !_isDisposed) {
        setState(() {
          _usesBiometric = usesBiometric && !_biometricFailed;
          _isLoading = false;
        });
        Logger.state('AuthScreen - Updated UI state: usesBiometric=$_usesBiometric, biometricFailed=$_biometricFailed');

        if (_usesBiometric && !_biometricFailed) {
          Logger.interaction('AuthScreen - Initiating biometric auth after delay');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_isDisposed) {
              _authenticateWithBiometric();
            }
          });
        } else {
          Logger.interaction('AuthScreen - Focusing PIN input');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDisposed) {
              _pinFocusNode.requestFocus();
            }
          });
        }
      }
    } catch (e, stack) {
      Logger.error('AuthScreen - Error checking security setup', e, stack);
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _usesBiometric = false;
        });
      }
    }
  }

  Future<void> _navigateToHome() async {
    Logger.interaction('AuthScreen - Attempting to navigate to home');
    if (_user == null) {
      Logger.state('AuthScreen - Navigation blocked: user is null');
      return;
    }
    
    try {
      if (mounted && !_isDisposed) {
        Logger.lifecycle('AuthScreen - Navigating to home screen');
        // Reset authenticating flag before navigation
        setState(() {
          _isAuthenticating = false;
        });
        
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e, stack) {
      Logger.error('AuthScreen - Navigation error', e, stack);
      if (mounted && !_isDisposed) {
        setState(() {
          _isAuthenticating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error navigating to home screen. Please try again.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _authenticateWithBiometric() async {
    if (_isAuthenticating) {
      Logger.state('AuthScreen - Biometric auth blocked: already authenticating');
      return;
    }
    
    try {
      Logger.interaction('AuthScreen - Starting biometric authentication');
      setState(() {
        _isAuthenticating = true;
      });
      
      final (authenticated, errorMessage) = await _securityService.authenticateWithBiometrics();
      Logger.state('AuthScreen - Biometric result: authenticated=$authenticated, error=$errorMessage');
      
      if (!mounted || _isDisposed) {
        Logger.lifecycle('AuthScreen - Widget disposed during biometric auth');
        return;
      }

      if (authenticated) {
        Logger.interaction('AuthScreen - Biometric auth successful, navigating');
        await _navigateToHome();
      } else {
        setState(() {
          _isAuthenticating = false;
          _biometricFailed = true;
          _usesBiometric = false;
        });
        
        if (errorMessage != null && mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              backgroundColor: AppColors.surface,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Use PIN',
                textColor: AppColors.primary,
                onPressed: () {
                  Logger.interaction('AuthScreen - User chose to use PIN');
                  if (mounted && !_isDisposed) {
                    setState(() {
                      _usesBiometric = false;
                    });
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
        
        Logger.interaction('AuthScreen - Auto-focusing PIN input after biometric failure');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposed) {
            _pinFocusNode.requestFocus();
          }
        });
      }
    } catch (e, stack) {
      Logger.error('AuthScreen - Error during biometric authentication', e, stack);
      if (mounted && !_isDisposed) {
        setState(() {
          _isAuthenticating = false;
          _biometricFailed = true;
          _usesBiometric = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'An error occurred during biometric authentication. Please use your PIN.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.surface,
            duration: Duration(seconds: 3),
          ),
        );
        
        Logger.interaction('AuthScreen - Focusing PIN input after biometric error');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposed) {
            _pinFocusNode.requestFocus();
          }
        });
      }
    }
  }

  Future<void> _verifyPin(String pin) async {
    if (_isAuthenticating) {
      Logger.state('AuthScreen - PIN verification blocked: already authenticating');
      return;
    }
    
    try {
      Logger.interaction('AuthScreen - Starting PIN verification');
      setState(() {
        _isAuthenticating = true;
      });
      
      final isValid = await _securityService.verifyPin(pin);
      Logger.state('AuthScreen - PIN verification result: $isValid');
      
      if (!mounted || _isDisposed) {
        Logger.lifecycle('AuthScreen - Widget disposed during PIN verification');
        return;
      }
      
      if (isValid) {
        Logger.interaction('AuthScreen - PIN verified, navigating to home');
        await _navigateToHome();
      } else {
        setState(() {
          _isAuthenticating = false;
          _pin = '';
        });
        
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Invalid PIN. Please try again.',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        Logger.interaction('AuthScreen - Refocusing PIN input after failure');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposed) {
            _pinFocusNode.requestFocus();
          }
        });
      }
    } catch (e, stack) {
      Logger.error('AuthScreen - Error during PIN verification', e, stack);
      if (mounted && !_isDisposed) {
        setState(() {
          _isAuthenticating = false;
          _pin = '';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'An error occurred. Please try again.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Logger.lifecycle('AuthScreen - Building UI');
    if (_isLoading) {
      Logger.state('AuthScreen - Showing loading state');
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    const TextStyle pinTextStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );

    Logger.state('AuthScreen - Building main UI: usesBiometric=$_usesBiometric, authenticating=$_isAuthenticating');
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Authentication Required'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              _buildAuthBanner(),
              if (_usesBiometric) ...[
                const Icon(
                  Icons.fingerprint,
                  size: 72,
                  color: AppColors.info,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isAuthenticating ? null : _authenticateWithBiometric,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isAuthenticating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                          ),
                        )
                      : const Text('Authenticate with Biometric'),
                ),
                TextButton(
                  onPressed: _isAuthenticating
                      ? null
                      : () {
                          Logger.interaction('AuthScreen - User chose to switch to PIN');
                          if (mounted && !_isDisposed) {
                            setState(() {
                              _usesBiometric = false;
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !_isDisposed) {
                                _pinFocusNode.requestFocus();
                              }
                            });
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Use PIN Instead'),
                ),
              ] else ...[
                const Text(
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
                    enabled: !_isAuthenticating,
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
                    onCompleted: (pin) {
                      Logger.interaction('AuthScreen - PIN entry completed');
                      _verifyPin(pin);
                    },
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
                if (!_biometricFailed)
                  TextButton(
                    onPressed: _isAuthenticating
                        ? null
                        : () {
                            Logger.interaction('AuthScreen - User chose to switch to biometric');
                            if (mounted && !_isDisposed) {
                              setState(() {
                                _usesBiometric = true;
                                _biometricFailed = false;
                              });
                              _authenticateWithBiometric();
                            }
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Use Biometric Instead'),
                  ),
                TextButton(
                  onPressed: _isAuthenticating
                      ? null
                      : () {
                          Logger.interaction('AuthScreen - User tapped Forgot PIN');
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Forgot PIN?'),
                ),
              ],
              _buildSecurityReminder(),
            ],
          ),
        ),
      ),
    );
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
                  style: const TextStyle(
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
            style: const TextStyle(
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
      child: const Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppColors.warning,
            size: 20,
          ),
          SizedBox(width: 8),
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
}
