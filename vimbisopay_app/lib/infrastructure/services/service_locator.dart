import 'package:http/http.dart' as http;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:vimbisopay_app/infrastructure/services/storage/storage_service.dart';
import 'package:vimbisopay_app/infrastructure/services/storage/storage_service_provider.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/domain/repositories/analytics/analytics_provider.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/repositories/analytics/firebase_analytics_provider.dart';
import 'package:vimbisopay_app/infrastructure/repositories/marketplace/marketplace_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/services/analytics_service.dart';
import 'package:vimbisopay_app/infrastructure/services/app_update_service.dart';
import 'package:vimbisopay_app/infrastructure/services/config_manager.dart';
import 'package:vimbisopay_app/infrastructure/services/location_service.dart';
import 'package:vimbisopay_app/infrastructure/services/password_service.dart';
import 'package:vimbisopay_app/infrastructure/services/remote_config_service.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/infrastructure/services/notification_service.dart';
import 'package:vimbisopay_app/infrastructure/services/feature_flag_service.dart';
import 'package:vimbisopay_app/infrastructure/services/store_status_service.dart';
import 'package:vimbisopay_app/infrastructure/services/connectivity_service.dart';
import 'package:vimbisopay_app/infrastructure/services/app_state_manager.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';

class ServiceLocator {

  
  // Services
  static final SecurityService _securityService = SecurityService();
  static final DatabaseHelper _databaseHelper = DatabaseHelper();
  static final http.Client _httpClient = http.Client();
  static final NotificationService _notificationService = NotificationService();
  static final LocationService _locationService = LocationService();
  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final AppStateManager _appStateManager = AppStateManager();
  
  // Analytics providers and service
  static final FirebaseAnalyticsProvider _firebaseAnalyticsProvider = FirebaseAnalyticsProvider(_analytics);
  static AnalyticsService? _analyticsService;
  
  // Lazy-initialized services that require async initialization
  static FeatureFlagService? _featureFlagService;
  static RemoteConfigService? _remoteConfigService;
  static AppUpdateService? _appUpdateService;
  static ConfigManager? _configManager;
  static ConnectivityService? _connectivityService;
  
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
    baseUrl: ApiConfig.baseUrl,
    databaseHelper: _databaseHelper,
    accountRepository: accountRepository,
  );
  
  static final StoreStatusService _storeStatusService = StoreStatusService(
    marketplaceRepository: marketplaceRepository,
    databaseHelper: _databaseHelper,
    locationService: _locationService,
  );

  // Private constructor to prevent instantiation
  ServiceLocator._();

  // Getters for services
  static SecurityService get securityService => _securityService;
  static PasswordService get passwordService => _passwordService;
  static DatabaseHelper get databaseHelper => _databaseHelper;
  static http.Client get httpClient => _httpClient;
  static NotificationService get notificationService => _notificationService;
  static LocationService get locationService => _locationService;
  static StoreStatusService get storeStatusService => _storeStatusService;
  static FirebaseAnalytics get analytics => _analytics;
  static AppStateManager get appStateManager => _appStateManager;
  
  // Getter for AnalyticsService with lazy initialization
  static AnalyticsService get analyticsService {
    if (_analyticsService == null) {
      throw Exception('AnalyticsService not initialized. Call initializeAnalyticsService() first.');
    }
    return _analyticsService!;
  }
  
  // Getter for ConnectivityService with lazy initialization
  static ConnectivityService get connectivityService {
    if (_connectivityService == null) {
      throw Exception('ConnectivityService not initialized. Call initializeConnectivityService() first.');
    }
    return _connectivityService!;
  }
  
  // Getter for FeatureFlagService with lazy initialization
  static FeatureFlagService get featureFlagService {
    if (_featureFlagService == null) {
      throw Exception('FeatureFlagService not initialized. Call initializeFeatureFlagService() first.');
    }
    return _featureFlagService!;
  }
  
  // Getter for RemoteConfigService with lazy initialization
  static RemoteConfigService get remoteConfigService {
    if (_remoteConfigService == null) {
      throw Exception('RemoteConfigService not initialized. Call initializeConfigServices() first.');
    }
    return _remoteConfigService!;
  }
  
  // Getter for AppUpdateService with lazy initialization
  static AppUpdateService get appUpdateService {
    if (_appUpdateService == null) {
      throw Exception('AppUpdateService not initialized. Call initializeConfigServices() first.');
    }
    return _appUpdateService!;
  }
  
  // Getter for ConfigManager with lazy initialization
  static ConfigManager get configManager {
    if (_configManager == null) {
      throw Exception('ConfigManager not initialized. Call initializeConfigServices() first.');
    }
    return _configManager!;
  }
  
  // Getter for StorageService
  static StorageService get storageService => StorageServiceProvider.storageService;
  
  // Initialize StorageService
  static Future<StorageService> initializeStorageService() async {
    return await StorageServiceProvider.initialize();
  }
  
  // Initialize FeatureFlagService
  static Future<FeatureFlagService> initializeFeatureFlagService() async {
    if (_featureFlagService != null) {
      return _featureFlagService!;
    }
    
    // Initialize storage service if not already initialized
    final storage = await initializeStorageService();
    _featureFlagService = FeatureFlagService(_remoteConfig, storage);
    return _featureFlagService!;
  }
  
  // Initialize all config services
  static Future<ConfigManager> initializeConfigServices() async {
    if (_configManager != null) {
      return _configManager!;
    }
    
    // Initialize StorageService if not already initialized
    final storage = await initializeStorageService();
    
    // Initialize FeatureFlagService if not already initialized
    if (_featureFlagService == null) {
      await initializeFeatureFlagService();
    }
    
    // Initialize RemoteConfigService
    _remoteConfigService = RemoteConfigService(_httpClient, storage, ApiConfig.baseUrl);
    await _remoteConfigService!.initialize();
    
    // Initialize AppUpdateService
    _appUpdateService = AppUpdateService(_httpClient, storage, ApiConfig.baseUrl);
    
    // Initialize ConfigManager
    _configManager = ConfigManager(
      _featureFlagService!,
      _remoteConfigService!,
      _appUpdateService!,
    );
    await _configManager!.initialize();
    
    return _configManager!;
  }
  
  // Initialize AnalyticsService
  static Future<AnalyticsService> initializeAnalyticsService() async {
    if (_analyticsService != null) {
      return _analyticsService!;
    }
    
    // Create a list of analytics providers
    final providers = <AnalyticsProvider>[
      _firebaseAnalyticsProvider,
      // Add more providers here as needed
    ];
    
    // Create and initialize the analytics service
    _analyticsService = AnalyticsService(providers);
    await _analyticsService!.initialize();
    
    return _analyticsService!;
  }
  
  // Initialize ConnectivityService
  static Future<ConnectivityService> initializeConnectivityService() async {
    if (_connectivityService != null) {
      return _connectivityService!;
    }
    
    _connectivityService = ConnectivityService();
    await _connectivityService!.initialize();
    return _connectivityService!;
  }
  
  // API configuration
  static String get apiBaseUrl => ApiConfig.baseUrl;
}
