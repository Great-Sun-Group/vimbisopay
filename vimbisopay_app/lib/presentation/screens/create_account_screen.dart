import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:country_picker/country_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/screens/security_setup_screen.dart';

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
  final _verifyPasswordController = TextEditingController();
  final _accountRepository = AccountRepositoryImpl();
  final _random = Random();
  bool _acceptedTerms = false;
  String? _passwordError;
  String? _verifyPasswordError;
  bool _isLoading = false;
  Country _selectedCountry = Country(
    phoneCode: '263',
    countryCode: 'ZW',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'Zimbabwe',
    example: '771234567',
    displayName: 'Zimbabwe (ZW)',
    displayNameNoCountryCode: 'Zimbabwe',
    e164Key: '263',
  );

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.info.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.info,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Why we need your information',
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
            'Your phone number will be your unique identifier for secure transactions. We use your name to personalize your experience and verify your identity when sending or receiving money.',
            style: TextStyle(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  bool _validatePhoneNumber(String phoneNumber) {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    return cleanPhone.length >= 7 && cleanPhone.length <= 15;
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country;
        });
      },
      countryListTheme: CountryListThemeData(
        borderRadius: BorderRadius.circular(12),
        backgroundColor: AppColors.surface,
        textStyle: TextStyle(color: AppColors.textPrimary),
        searchTextStyle: TextStyle(color: AppColors.textPrimary),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          labelStyle: TextStyle(color: AppColors.textSecondary),
          prefixIcon: Icon(Icons.search, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Future<void> _launchTermsUrl() async {
    final Uri url = Uri.parse('https://docs.mycredex.app/index.html');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Error', style: TextStyle(color: AppColors.error)),
        content: Text(message, style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _onCreateAccount() async {
    if (!_formKey.currentState!.validate() || !_acceptedTerms) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );

      final fullPhoneNumber = '+${_selectedCountry.phoneCode}${_phoneController.text.replaceAll(RegExp(r'\s+'), '')}';

      final onboardResponse = await _accountRepository.onboardMember(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: fullPhoneNumber,
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.pop(context); // Remove loading dialog

      final onboardSuccess = await onboardResponse.fold(
        (failure) async {
          _showError(failure.message ?? 'Failed to create account. Please try again.');
          return false;
        },
        (_) async => true,
      );

      if (!onboardSuccess) return;

      final loginResult = await _accountRepository.login(
        phone: fullPhoneNumber,
        password: _passwordController.text,
      );

      if (!mounted) return;

      loginResult.fold(
        (failure) {
          _showError(failure.message ?? 'Failed to login after account creation. Please try logging in manually.');
        },
        (user) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SecuritySetupScreen(user: user),
            ),
          );
        },
      );
    } catch (e) {
      print(e);
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
        borderSide: BorderSide(color: AppColors.primary),
      ),
      labelStyle: TextStyle(color: AppColors.textSecondary),
      helperStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
      errorStyle: TextStyle(color: AppColors.error),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: inputDecorationTheme,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome to VimbisoPay!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Create your account to start sending and receiving money securely across borders.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                _buildInfoBanner(),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    helperText: 'Enter your legal first name as it appears on your ID',
                  ),
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
                    helperText: 'Enter your legal last name as it appears on your ID',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: InkWell(
                            onTap: _showCountryPicker,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Row(
                                children: [
                                  Text(_selectedCountry.flagEmoji),
                                  const SizedBox(width: 8),
                                  Text(
                                    '+${_selectedCountry.phoneCode}',
                                    style: TextStyle(color: AppColors.textPrimary),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              hintText: _selectedCountry.example,
                              helperText: 'This will be your unique login identifier',
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (!_validatePhoneNumber(value)) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: _passwordError,
                    helperText: 'Must be at least 6 characters long',
                    suffixIcon: Icon(Icons.lock_outline, color: AppColors.primary),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _verifyPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Verify Password',
                    errorText: _verifyPasswordError,
                    helperText: 'Re-enter your password to confirm',
                    suffixIcon: Icon(Icons.lock_outline, color: AppColors.primary),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please verify your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: Wrap(
                    children: [
                      Text(
                        'I accept the ',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      GestureDetector(
                        onTap: _launchTermsUrl,
                        child: Text(
                          'terms and conditions',
                          style: TextStyle(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  value: _acceptedTerms,
                  onChanged: (bool? value) {
                    setState(() {
                      _acceptedTerms = value ?? false;
                    });
                  },
                  activeColor: AppColors.primary,
                  checkColor: AppColors.textPrimary,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading || !_acceptedTerms ? null : _onCreateAccount,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Debug-only extension that will be tree-shaken in release builds
extension CreateAccountDebug on _CreateAccountScreenState {
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(_random.nextInt(chars.length))));
  }

  String _generateRandomPhoneNumber() {
    final randomDigits = List.generate(7, (_) => _random.nextInt(10)).join();
    return '77$randomDigits';
  }

  void _debugFillTestData() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomName = _generateRandomString(5);
    
    _firstNameController.text = 'Test$randomName';
    _lastNameController.text = 'User$timestamp'.substring(0, 10);
    _phoneController.text = _generateRandomPhoneNumber();
    
    final password = 'pass${timestamp.toString().substring(8)}';
    _passwordController.text = password;
    _verifyPasswordController.text = password;
    
    setState(() {
      _acceptedTerms = true;
    });
  }
}