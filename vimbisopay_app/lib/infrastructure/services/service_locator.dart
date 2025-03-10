import 'package:http/http.dart' as http;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/repositories/marketplace/marketplace_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/services/password_service.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/infrastructure/services/notification_service.dart';
import 'package:vimbisopay_app/infrastructure/services/feature_flag_service.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';

class ServiceLocator {
  // API configuration
  static const String _apiBaseUrl = 'https://api.vimbisopay.com/v1';
  
  // Services
  static final SecurityService _securityService = SecurityService();
  static final DatabaseHelper _databaseHelper = DatabaseHelper();
  static final http.Client _httpClient = http.Client();
  static final NotificationService _notificationService = NotificationService();
  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  // Lazy-initialized services that require async initialization
  static FeatureFlagService? _featureFlagService;
  
  static final PasswordService _passwordService = PasswordService(
    securityService: _securityService,
    databaseHelper: _databaseHelper,
    httpClient: _httpClient,
  );

  // Repositories
  static final AccountRepositoryImpl accountRepository = AccountRepositoryImpl(
    passwordService: _passwordService,
    databaseHelper: _databaseHelper,
    httpClient: _httpClient,
  );
  
  static final MarketplaceRepository marketplaceRepository = MarketplaceRepositoryImpl(
    httpClient: _httpClient,
    baseUrl: '$_apiBaseUrl/marketplace',
  );

  // Private constructor to prevent instantiation
  ServiceLocator._();

  // Getters for services
  static SecurityService get securityService => _securityService;
  static PasswordService get passwordService => _passwordService;
  static DatabaseHelper get databaseHelper => _databaseHelper;
  static http.Client get httpClient => _httpClient;
  static NotificationService get notificationService => _notificationService;
  static FirebaseAnalytics get analytics => _analytics;
  
  // Getter for FeatureFlagService with lazy initialization
  static FeatureFlagService get featureFlagService {
    if (_featureFlagService == null) {
      throw Exception('FeatureFlagService not initialized. Call initializeFeatureFlagService() first.');
    }
    return _featureFlagService!;
  }
  
  // Initialize FeatureFlagService
  static Future<FeatureFlagService> initializeFeatureFlagService() async {
    if (_featureFlagService != null) {
      return _featureFlagService!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    _featureFlagService = FeatureFlagService(_remoteConfig, prefs);
    return _featureFlagService!;
  }
  
  // API configuration
  static String get apiBaseUrl => _apiBaseUrl;
}
