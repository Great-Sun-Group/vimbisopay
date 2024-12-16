import 'package:flutter/material.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/screens/auth_screen.dart';
import 'package:vimbisopay_app/presentation/screens/settings_screen.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/application/usecases/get_member_dashboard.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final SecurityService _securityService = SecurityService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final AccountRepository _accountRepository = AccountRepositoryImpl();
  late final GetMemberDashboard _getMemberDashboard;
  
  bool _isCheckingAuth = false;
  bool _isLoadingDashboard = false;
  Dashboard? _dashboard;
  String? _error;

  @override
  void initState() {
    super.initState();
    _getMemberDashboard = GetMemberDashboard(_accountRepository);
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
    if (_isCheckingAuth) return;
    
    setState(() {
      _isCheckingAuth = true;
      _error = null;
    });

    try {
      final requiresAuth = await _securityService.requiresAuthentication();
      if (requiresAuth && mounted) {
        final user = await _databaseHelper.getUser();
        if (user != null && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AuthScreen(user: user),
            ),
          );
          // After successful authentication, fetch dashboard
          _fetchDashboard();
        } else if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        // If no auth required, fetch dashboard directly
        _fetchDashboard();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  Future<void> _fetchDashboard() async {
    if (!mounted) return;

    setState(() {
      _isLoadingDashboard = true;
      _error = null;
    });

    try {
      final user = await _databaseHelper.getUser();
      if (user != null) {
        final result = await _getMemberDashboard.execute(user.phone);
        
        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _error = failure.message;
                _isLoadingDashboard = false;
              });
            }
          },
          (dashboard) {
            if (mounted) {
              setState(() {
                _dashboard = dashboard;
                _isLoadingDashboard = false;
              });
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load dashboard';
          _isLoadingDashboard = false;
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

  void _retryFetch() {
    _fetchDashboard();
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
              if (_isCheckingAuth || _isLoadingDashboard)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              else if (_error != null)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _retryFetch,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_dashboard != null)
                Column(
                  children: [
                    Text(
                      'Welcome, ${_dashboard!.firstname} ${_dashboard!.lastname}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Card(
                      color: AppColors.surface,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Text(
                              'Member Handle',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              _dashboard!.memberHandle,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (_dashboard!.accounts.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              const Text(
                                'Balance',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _dashboard!.accounts.first.balanceData.netCredexAssetsInDefaultDenom,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
