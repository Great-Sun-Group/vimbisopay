import 'package:flutter/material.dart';
import '../../infrastructure/services/security_service.dart';
import '../../infrastructure/database/database_helper.dart';
import '../../core/theme/app_colors.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final SecurityService _securityService = SecurityService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isCheckingAuth = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthentication();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAuthentication();
    }
  }

  Future<void> _checkAuthentication() async {
    // Prevent multiple simultaneous checks
    if (_isCheckingAuth) return;
    
    setState(() {
      _isCheckingAuth = true;
    });

    try {
      final requiresAuth = await _securityService.requiresAuthentication();
      if (requiresAuth && mounted) {
        final user = await _databaseHelper.getUser();
        if (user != null && mounted) {
          // Show authentication screen with user data
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AuthScreen(user: user),
            ),
          );
        } else if (mounted) {
          // If no user data, redirect to login
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  void _onSettingsTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _onSettingsTap,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to VimbisoPay',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your account has been created successfully!',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (_isCheckingAuth) ...[
                const SizedBox(height: 24),
                Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
