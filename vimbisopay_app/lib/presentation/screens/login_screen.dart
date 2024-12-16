import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/screens/auth_screen.dart';
import 'package:vimbisopay_app/presentation/screens/forgot_password_screen.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repository = AccountRepositoryImpl();
  final _databaseHelper = DatabaseHelper();
  bool _isFormValid = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
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
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _phoneController.text.isNotEmpty && 
                     _passwordController.text.isNotEmpty &&
                     _passwordController.text.length >= 6;
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
      child: Column(
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome Back!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
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
      child: Row(
        children: [
          Icon(
            Icons.security_outlined,
            color: AppColors.info,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your security is our priority. We use industry-standard encryption to protect your information.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary.withOpacity(0.7),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: AppColors.error,
                ),
                const SizedBox(height: 24),
                Text(
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
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final phoneNumber = '+${_phoneController.text}';
      
      final result = await _repository.login(
        phone: phoneNumber,
        password: _passwordController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        result.fold(
          (failure) {
            _showErrorDialog(
              'We couldn\'t log you in. Please check your phone number and password, then try again.',
            );
          },
          (user) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AuthScreen(user: user),
              ),
            );
          },
        );
      }
    }
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
              Form(
                key: _formKey,
                onChanged: _validateForm,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.phone),
                        hintText: '263712345678 or 353871234567',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.5),
                          fontSize: 14,
                        ),
                        helperText: 'Start with country code (e.g. 263 for Zimbabwe, 353 for Ireland)',
                        helperStyle: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        helperMaxLines: 2,
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                      keyboardType: TextInputType.phone,
                      enabled: !_isLoading,
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        helperText: 'Enter the password you created during registration',
                        filled: true,
                        fillColor: AppColors.surface,
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
                      onPressed: _isFormValid && !_isLoading ? _handleLogin : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
