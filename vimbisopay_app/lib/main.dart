import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vimbisopay_app/infrastructure/services/notification_service.dart';
import 'package:vimbisopay_app/presentation/screens/intro_screen.dart';
import 'package:vimbisopay_app/presentation/screens/create_account_screen.dart';
import 'package:vimbisopay_app/presentation/screens/home_screen.dart';
import 'package:vimbisopay_app/presentation/screens/login_screen.dart';
import 'package:vimbisopay_app/presentation/screens/auth_screen.dart';
import 'package:vimbisopay_app/presentation/screens/settings_screen.dart';
import 'package:vimbisopay_app/presentation/screens/send_credex_screen.dart';
import 'package:vimbisopay_app/presentation/screens/security_setup_screen.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/presentation/models/send_credex_arguments.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize notifications
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VimbisoPay',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.error,
          onPrimary: AppColors.textPrimary,
          onSecondary: AppColors.textPrimary,
          onSurface: AppColors.textPrimary,
          onError: AppColors.textPrimary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textPrimary),
          titleLarge: TextStyle(color: AppColors.textPrimary),
          titleMedium: TextStyle(color: AppColors.textPrimary),
          titleSmall: TextStyle(color: AppColors.textSecondary),
        ),
      ),
      onGenerateRoute: (settings) {
        // Protected routes that require authentication
        if (settings.name == '/home') {
          return MaterialPageRoute(
            builder: (context) => const HomeScreen(),
            settings: settings,
          );
        }

        if (settings.name == '/settings') {
          return MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
            settings: settings,
          );
        }

        if (settings.name == '/send-credex') {
          final args = settings.arguments as SendCredexArguments?;
          if (args == null) {
            Logger.error('No arguments provided for send-credex route');
            return MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            );
          }
          return MaterialPageRoute(
            builder: (context) => SendCredexScreen(
              senderAccount: args.senderAccount,
              accountRepository: args.accountRepository,
              homeBloc: args.homeBloc,
              databaseHelper: args.databaseHelper,
            ),
            settings: settings,
          );
        }

        // Auth routes
        if (settings.name == '/auth') {
          final user = settings.arguments as User?;
          if (user == null) {
            Logger.state('No user provided for auth, redirecting to login');
            return MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            );
          }
          return MaterialPageRoute(
            builder: (context) => AuthScreen(user: user),
            settings: settings,
          );
        }

        if (settings.name == '/security-setup') {
          final user = settings.arguments as User?;
          if (user == null) {
            Logger.state('No user provided for security setup, redirecting to login');
            return MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            );
          }
          return MaterialPageRoute(
            builder: (context) => SecuritySetupScreen(user: user),
            settings: settings,
          );
        }

        // Public routes
        if (settings.name == '/login') {
          return MaterialPageRoute(
            builder: (context) => const LoginScreen(),
            settings: settings,
          );
        }

        if (settings.name == '/create-account') {
          return MaterialPageRoute(
            builder: (context) => const CreateAccountScreen(),
            settings: settings,
          );
        }

        // Default to intro wrapper for unknown routes
        return MaterialPageRoute(
          builder: (context) => const IntroWrapper(),
        );
      },
      home: const IntroWrapper(),
    );
  }
}

class IntroWrapper extends StatefulWidget {
  const IntroWrapper({super.key});

  @override
  State<IntroWrapper> createState() => _IntroWrapperState();
}

class _IntroWrapperState extends State<IntroWrapper> {
  bool _showIntro = true;
  bool _loading = true;
  bool _hasExistingUser = false;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final SecurityService _securityService = SecurityService();

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasShownIntro = prefs.getBool('hasShownIntro') ?? false;
      
      // First check if we have a user in the database
      final hasUser = await _databaseHelper.hasUser();
      
      User? user;
      if (hasUser) {
        // Only try to get user data if we know a user exists
        try {
          user = await _databaseHelper.getUser();
        } catch (e) {
          // If there's an error getting user data, delete corrupted data
          Logger.error('Error getting user data', e);
          await _databaseHelper.deleteUser();
        }
      }
      
      final isSecuritySetup = await _securityService.isSecuritySetup();
      
      if (mounted) {
        setState(() {
          _showIntro = !hasShownIntro;
          _hasExistingUser = user != null;
          _loading = false;
        });

        // If we have a valid user and security is set up, go to auth screen
        if (user != null && isSecuritySetup && mounted) {
          Logger.state('Valid user found, navigating to auth');
          Navigator.pushReplacementNamed(
            context, 
            '/auth',
            arguments: user,
          );
        }
      }
    } catch (e) {
      Logger.error('Error in initial state check', e);
      if (mounted) {
        setState(() {
          _loading = false;
          _hasExistingUser = false;
        });
      }
    }
  }

  Future<void> _onIntroComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasShownIntro', true);
    
    if (mounted) {
      setState(() {
        _showIntro = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    // If we have an existing user but haven't checked auth yet, show login
    if (_hasExistingUser) {
      return const LoginScreen();
    }

    // Otherwise show intro or login/signup options
    if (_showIntro) {
      return IntroScreen(onComplete: _onIntroComplete);
    }

    return const LoginSignupScreen();
  }
}

class LoginSignupScreen extends StatelessWidget {
  const LoginSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                // App Logo
                Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'lib/assets/images/app-logo.jpeg',
                      height: 120,
                      width: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const Text(
                  'Welcome to VimbisoPay',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                FilledButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/create-account');
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('hasShownIntro');
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const IntroWrapper()),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Reset Intro (Debug)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
