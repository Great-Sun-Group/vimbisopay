import 'package:http/http.dart' as http;
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/services/password_service.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/infrastructure/services/notification_service.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';

class ServiceLocator {
  static final SecurityService _securityService = SecurityService();
  static final DatabaseHelper _databaseHelper = DatabaseHelper();
  static final http.Client _httpClient = http.Client();
  static final NotificationService _notificationService = NotificationService();
  
  static final PasswordService _passwordService = PasswordService(
    securityService: _securityService,
    databaseHelper: _databaseHelper,
    httpClient: _httpClient,
  );

  static final AccountRepositoryImpl accountRepository = AccountRepositoryImpl(
    passwordService: _passwordService,
    databaseHelper: _databaseHelper,
    httpClient: _httpClient,
  );

  // Private constructor to prevent instantiation
  ServiceLocator._();

  // Getters for services
  static SecurityService get securityService => _securityService;
  static PasswordService get passwordService => _passwordService;
  static DatabaseHelper get databaseHelper => _databaseHelper;
  static http.Client get httpClient => _httpClient;
  static NotificationService get notificationService => _notificationService;
}
