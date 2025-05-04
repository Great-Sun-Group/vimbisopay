import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/presentation/blocs/notifications/notifications_bloc.dart';
import 'package:vimbisopay_app/presentation/screens/intro_screen.dart';
import 'package:vimbisopay_app/presentation/screens/create_account_screen.dart';
import 'package:vimbisopay_app/presentation/screens/home_screen.dart';
import 'package:vimbisopay_app/presentation/screens/login_screen.dart';
import 'package:vimbisopay_app/presentation/screens/auth_screen.dart';
import 'package:vimbisopay_app/presentation/screens/settings_screen.dart';
import 'package:vimbisopay_app/presentation/screens/send_credex_screen.dart';
import 'package:vimbisopay_app/presentation/screens/security_setup_screen.dart';
import 'package:vimbisopay_app/presentation/screens/notifications_settings_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/vendor_profile_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/vendor_registration_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/invoicing/vendor_sales_tab_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/invoicing/buyer_invoice_detail_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/search_results_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/product_detail_screen.dart';
import 'package:vimbisopay_app/presentation/screens/debug_screen.dart';
import 'package:vimbisopay_app/presentation/widgets/test_whatsapp_otp.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/utils/database_test.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/navigation_utils.dart';
import 'package:vimbisopay_app/core/utils/crash_tracker.dart';
import 'package:vimbisopay_app/core/utils/deep_link_handler.dart';
import 'package:vimbisopay_app/presentation/models/send_credex_arguments.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/connectivity_banner.dart';
import 'package:vimbisopay_app/presentation/screens/app_update_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    print('=== BACKGROUND MESSAGE RECEIVED ===');

    // Initialize Firebase for background handler
    print('Initializing Firebase in background handler...');
    await Firebase.initializeApp();
    print('Firebase initialized in background handler');

    print('''
Message details:
- Message ID: ${message.messageId}
- Title: ${message.notification?.title}
- Body: ${message.notification?.body}
- Data: ${message.data}
- Category: ${message.category}
- SenderId: ${message.senderId}
- ThreadId: ${message.threadId}
- From: ${message.from}
- SentTime: ${message.sentTime}
''');

    // Initialize NotificationService to handle background message
    print('Initializing NotificationService in background...');
    final notificationService = ServiceLocator.notificationService;
    final initialized = await notificationService.initialize();

    if (initialized) {
      print('NotificationService initialized in background');

      // Play notification sound
      await notificationService.playNotificationSound();
      print('Notification sound played in background');

      // Create a new message with the same data
      final processedMessage = RemoteMessage(
        notification: message.notification,
        data: Map<String, String>.from(message.data),
        messageId: message.messageId,
        senderId: message.senderId,
        category: message.category,
        from: message.from,
        sentTime: message.sentTime,
        threadId: message.threadId,
      );

      // Send message through notification service to trigger the same flow as foreground
      print('Sending message through notification service...');
      notificationService.sendTestNotification(processedMessage);
      print('Message sent through notification service');

      // Initialize database helper to refresh data
      print('Initializing database helper...');
      final databaseHelper = ServiceLocator.databaseHelper;
      final user = await databaseHelper.getUser();
      if (user != null) {
        print('User found, refreshing data...');
        // TODO: Implement background refresh
      } else {
        print('No user found in database');
      }
    } else {
      print('Failed to initialize NotificationService in background');
    }

    print('=== BACKGROUND MESSAGE HANDLING COMPLETE ===');
  } catch (e, stackTrace) {
    print('''
ERROR in background handler:
Error: $e
Stack trace: $stackTrace
''');
  }
}

void main() async {
  try {
    print('=== APP STARTING ===');
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables
    print('Loading environment variables...');
    await dotenv.load(fileName: '.env');
    print('Environment variables loaded successfully');
    
    // Initialize API configuration
    print('Initializing API configuration...');
    await ApiConfig.initialize();
    await ApiConfig.refreshEnvironment();
    print('API configuration initialized successfully');
    Logger.data('API environment: ${ApiConfig.environmentName}');

    // Initialize Firebase first
    print('Initializing Firebase...');
    await Firebase.initializeApp();
    print('Firebase initialized successfully');

    // Initialize Firebase Analytics
    print('Initializing Firebase Analytics...');
    final analytics = ServiceLocator.analytics;
    print('Firebase Analytics initialized successfully');
    
    // Initialize Analytics Service
    print('Initializing Analytics Service...');
    await ServiceLocator.initializeAnalyticsService();
    print('Analytics Service initialized successfully');
    
    // Set up global error handler for tracking crashes
    print('Setting up global error handler...');
    CrashTracker.setupGlobalErrorHandler();
    print('Global error handler set up successfully');

    // Set up background message handler
    print('Setting up background message handler...');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    print('Background message handler set up');

    // Initialize config services with cached values first
    print('Initializing config services...');
    final configManager = await ServiceLocator.initializeConfigServices();

    Logger.data('ConfigManager initialized successfully');
    Logger.data(
        'Marketplace feature enabled: ${configManager.isFeatureEnabled('enable_marketplace')}');
        
    // Force refresh all configuration in the background
    Future.delayed(const Duration(milliseconds: 500), () async {
      print('Refreshing all configuration on app start...');
      final refreshed = await configManager.refreshAll();
      Logger.data('Configuration refresh on app start result: $refreshed');
      
      if (refreshed) {
        Logger.data('Configuration refreshed successfully on app start');
        Logger.data(
            'Marketplace feature enabled after refresh: ${configManager.isFeatureEnabled('enable_marketplace')}');
      } else {
        Logger.error('Failed to refresh configuration on app start');
      }
    });

    // Schedule app updates check for after UI is rendered
    Future.delayed(const Duration(seconds: 2), () async {
      print('Checking for app updates in background...');
      final updateInfo = await configManager.checkForUpdate();
      if (updateInfo != null) {
        Logger.data('Update available: ${updateInfo['latest_version']}');
        Logger.data('Update required: ${updateInfo['update_required']}');
        Logger.data('Update priority: ${updateInfo['update_priority']}');
        
        // Show update screen
        await _showUpdateScreen(updateInfo);
      } else {
        Logger.data('No updates available');
      }
    });

    // Initialize NotificationService with basic setup first
    print('Initializing NotificationService...');
    final notificationService = ServiceLocator.notificationService;
    
    // Initialize ConnectivityService
    print('Initializing ConnectivityService...');
    await ServiceLocator.initializeConnectivityService();
    print('ConnectivityService initialized successfully');
    
    // Initialize DeepLinkHandler
    print('Initializing DeepLinkHandler...');
    await DeepLinkHandler.initialize();
    print('DeepLinkHandler initialized successfully');
    
    // Schedule full notification service initialization for after UI is rendered
    Future.delayed(const Duration(seconds: 1), () async {
      print('Completing NotificationService initialization in background...');
      final initialized = await notificationService.initialize();
      
      if (!initialized) {
        Logger.error('Failed to initialize NotificationService');
        return;
      }
      
      Logger.data('''
NotificationService initialized successfully:
- Has refresh controller: ${notificationService.onRefreshNeeded != null}
- Has notification controller: ${notificationService.onNotification != null}
''');
    });

    print('=== APP INITIALIZATION COMPLETE ===');
  } catch (e, stackTrace) {
    Logger.error('''
[NOTIFICATION_FLOW] Error during app initialization:
- Error: $e
- Stack trace: $stackTrace
''');
  }

  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(sharedPreferences: prefs));
}

/// Shows the app update screen.
///
/// This function shows a dialog with the update information and options to
/// download and install the update or defer it for later. It also ensures that
/// the current version is included in the update information.
///
/// The function gets the current app version using PackageInfo and adds it to
/// the updateInfo map if it's not already present.
// Global navigator key for accessing the navigator from outside the widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _showUpdateScreen(Map<String, dynamic> updateInfo) async {
  // Get current app version
  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;
  
  // Add current version to updateInfo if not already present
  if (!updateInfo.containsKey('current_version')) {
    updateInfo['current_version'] = currentVersion;
    Logger.data('Added current version to update info: $currentVersion');
  }
  
  // Wait for the app to be fully initialized
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      Logger.error('Cannot show update screen: no valid context');
      return;
    }
    
    // Set update screen showing state
    ServiceLocator.appStateManager.setUpdateScreenShowing(true);
    
    // Show the update screen as a dialog
    showDialog(
      context: context,
      barrierDismissible: updateInfo['update_required'] != true,
      builder: (context) => AppUpdateScreen(updateInfo: updateInfo),
    ).then((_) {
      // Reset state when dialog is dismissed
      ServiceLocator.appStateManager.setUpdateScreenShowing(false);
    });
  });
}

class MyApp extends StatelessWidget {
  final SharedPreferences sharedPreferences;

  const MyApp({
    required this.sharedPreferences,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: sharedPreferences),
        Provider<DatabaseHelper>.value(
          value: ServiceLocator.databaseHelper,
        ),
        BlocProvider(
          create: (context) => NotificationsBloc(sharedPreferences)
            ..add(NotificationsInitialize()),
        ),
        StreamProvider<User?>(
          create: (context) => context.read<DatabaseHelper>().userStream,
          initialData: null,
          catchError: (_, error) {
            Logger.error('Error in User stream provider', error);
            return null;
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'VimbisoPay',
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              Positioned(
                top: MediaQuery.of(context).padding.top, // Position below status bar
                left: 0,
                right: 0,
                child: const ConnectivityBanner(),
              ),
            ],
          );
        },
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

          if (settings.name == '/notifications-settings') {
            return MaterialPageRoute(
              builder: (context) => const NotificationsSettingsScreen(),
              settings: settings,
            );
          }

          if (settings.name == '/marketplace') {
            // Only allow access if the marketplace feature is enabled
            if (ServiceLocator.featureFlagService.isMarketplaceEnabled()) {
              return MaterialPageRoute(
                builder: (context) => const MarketplaceScreen(),
                settings: settings,
              );
            } else {
              // Redirect to home if marketplace is not enabled
              Logger.state(
                  'Marketplace feature is disabled, redirecting to home');
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              );
            }
          }

          // Search results screen
          if (settings.name == '/search-results') {
            if (!ServiceLocator.featureFlagService.isMarketplaceEnabled()) {
              return MaterialPageRoute(
                  builder: (context) => const HomeScreen());
            }
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => SearchResultsScreen(
                initialQuery: args?['query'] as String?,
                vendorId: args?['vendorId'] as String?,
                filterOwnProducts: args?['filterOwnProducts'] as bool? ?? false,
              ),
            );
          }

          // Product detail screen
          if (settings.name == '/product-detail') {
            if (!ServiceLocator.featureFlagService.isMarketplaceEnabled()) {
              return MaterialPageRoute(
                  builder: (context) => const HomeScreen());
            }
            final args = settings.arguments as Map<String, dynamic>?;
            if (args == null || !args.containsKey('productId')) {
              Logger.error('No product ID provided for product-detail route');
              return MaterialPageRoute(
                  builder: (context) => const MarketplaceScreen());
            }
            return MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                productId: args['productId'] as String,
              ),
            );
          }

          // Vendor profile screen route
          if (settings.name == '/vendor-profile') {
            // Only allow access if the marketplace feature is enabled
            if (ServiceLocator.featureFlagService.isMarketplaceEnabled()) {
              final args = settings.arguments as Map<String, dynamic>?;
              if (args == null || !args.containsKey('vendorId')) {
                Logger.error('No vendor ID provided for vendor-profile route');
                return MaterialPageRoute(
                  builder: (context) => const MarketplaceScreen(),
                );
              }

              return MaterialPageRoute(
                builder: (context) => VendorProfileScreen(
                  vendorId: args['vendorId'] as String,
                  isOwner: args['isOwner'] as bool? ?? false,
                ),
                settings: settings,
              );
            } else {
              // Redirect to home if marketplace is not enabled
              Logger.state(
                  'Marketplace feature is disabled, redirecting to home');
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              );
            }
          }

          // Vendor registration screen route
          if (settings.name == '/vendor-registration') {
            // Only allow access if the marketplace feature is enabled
            if (ServiceLocator.featureFlagService.isMarketplaceEnabled()) {
              final args = settings.arguments as Map<String, dynamic>?;
              if (args == null || !args.containsKey('memberId')) {
                Logger.error(
                    'No member ID provided for vendor-registration route');
                return MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                );
              }

              return MaterialPageRoute(
                builder: (context) => VendorRegistrationScreen(
                  memberId: args['memberId'] as String,
                  user: args['user'] as User?,
                ),
                settings: settings,
              );
            } else {
              // Redirect to home if marketplace is not enabled
              Logger.state(
                  'Marketplace feature is disabled, redirecting to home');
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              );
            }
          }

          // Vendor sales tab screen route
          if (settings.name == '/vendor-sales-tab') {
            // Only allow access if the marketplace feature is enabled
            if (ServiceLocator.featureFlagService.isMarketplaceEnabled()) {
              return MaterialPageRoute(
                builder: (context) => const VendorSalesTabScreen(),
                settings: settings,
              );
            } else {
              // Redirect to home if marketplace is not enabled
              Logger.state(
                  'Marketplace feature is disabled, redirecting to home');
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              );
            }
          }

          // Buyer invoice detail screen route
          if (settings.name == '/buyer-invoice-detail') {
            // Only allow access if the marketplace feature is enabled
            if (ServiceLocator.featureFlagService.isMarketplaceEnabled()) {
              final args = settings.arguments as Map<String, dynamic>?;
              if (args == null || !args.containsKey('invoiceId')) {
                Logger.error(
                    'No invoice ID provided for buyer-invoice-detail route');
                return MaterialPageRoute(
                  builder: (context) => const MarketplaceScreen(),
                );
              }

              return MaterialPageRoute(
                builder: (context) => BuyerInvoiceDetailScreen(
                  invoiceId: args['invoiceId'] as String,
                ),
                settings: settings,
              );
            } else {
              // Redirect to home if marketplace is not enabled
              Logger.state(
                  'Marketplace feature is disabled, redirecting to home');
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              );
            }
          }

          if (settings.name == '/debug') {
            return MaterialPageRoute(
              builder: (context) => const DebugScreen(),
              settings: settings,
            );
          }
          
          if (settings.name == '/test-whatsapp-otp') {
            return MaterialPageRoute(
              builder: (context) => const TestWhatsAppOTP(),
              settings: settings,
            );
          }
          
          if (settings.name == '/database-test') {
            return MaterialPageRoute(
              builder: (context) => const DatabaseTestScreen(),
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
                recipientHandle: args.recipientHandle,
                recipientAccountId: args.recipientAccountId,
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
              Logger.state(
                  'No user provided for security setup, redirecting to login');
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
      ),
    );
  }
}

class IntroWrapper extends StatefulWidget {
  const IntroWrapper({super.key});

  @override
  State<IntroWrapper> createState() => _IntroWrapperState();
}

class _IntroWrapperState extends State<IntroWrapper>
    with SingleTickerProviderStateMixin {
  bool _showIntro = true;
  bool _loading = true;
  bool _hasExistingUser = false;
  final _databaseHelper = ServiceLocator.databaseHelper;
  final _securityService = ServiceLocator.securityService;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );

    // Start the animation and make it repeat
    _animationController.repeat();

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
          NavigationUtils.safeNavigateReplacementTo(
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
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Lottie.asset(
            'assets/animations/loading_anim.json',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
            controller: _animationController,
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
                    NavigationUtils.safeNavigateTo(context, '/login');
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
                    NavigationUtils.safeNavigateTo(context, '/create-account');
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text(
                    'Become a Member',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('hasShownIntro');
                    if (context.mounted) {
                      NavigationUtils.safeNavigateReplacementTo(
                        context,
                        '/',
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
