import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:dartz/dartz.dart';
import 'package:meta/meta.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/core/error/exceptions.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/domain/entities/account.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart' as credex;
import 'package:vimbisopay_app/domain/entities/recurring_request.dart';
import 'package:vimbisopay_app/domain/entities/recurring_response.dart';
import 'package:vimbisopay_app/domain/entities/otp_verification_response.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/infrastructure/services/password_service.dart';
import 'package:vimbisopay_app/infrastructure/services/network_logger.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';
import 'package:vimbisopay_app/core/utils/phone_formatter.dart';

class AccountRepositoryImpl implements AccountRepository {
  final String baseUrl = ApiConfig.baseUrl;

  final DatabaseHelper _databaseHelper;
  final PasswordService _passwordService;
  final http.Client _httpClient;

  AccountRepositoryImpl({
    required PasswordService passwordService,
    DatabaseHelper? databaseHelper,
    http.Client? httpClient,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper(),
       _passwordService = passwordService,
       _httpClient = httpClient ?? http.Client();

  @override
  Future<Either<Failure, User>> loginV2({
    required String phone,
    String? password,
    String? passwordHash,
  }) async {
    try {
      // Format phone number before sending
      final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      Logger.data('[LOGIN_V2] Formatted phone number: $formattedPhone');

      final url = '$baseUrl/v2/login';
      final body = {
        'phone': formattedPhone,
      };

      // For v2 login, we send phone and hashed password
      if (password != null) {
        // Hash the password before sending
        final hash = await _passwordService.hashPassword(password);
        body['password'] = hash;
        // Store the hash for later use
        passwordHash = hash;
      } else if (passwordHash != null) {
        // For token refresh, use the stored hash
        body['password'] = passwordHash;
      }

      final response = await _loggedRequest(
        () => _httpClient.post(
          Uri.parse(url),
          headers: _baseHeaders,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: _baseHeaders,
        body: body,
      );

      final jsonResponse = json.decode(response.body);

      // Check for PASSWORD_REQUIRED error
      if (jsonResponse['data']?['action']?['details']?['code'] == 'PASSWORD_REQUIRED') {
        return Left(AuthFailure(
          message: jsonResponse['message'] ?? 'Password is required for this account',
          code: 'PASSWORD_REQUIRED',
        ));
      }

      if (response.statusCode == 200) {
        if (!jsonResponse.containsKey('data') ||
            !jsonResponse['data'].containsKey('action') ||
            !jsonResponse['data']['action'].containsKey('details') ||
            !jsonResponse['data'].containsKey('dashboard')) {
          return const Left(InfrastructureFailure('Invalid response format'));
        }

        final actionDetails = jsonResponse['data']['action']['details'];
        final dashboardData = jsonResponse['data']['dashboard'];

        final memberId = actionDetails['memberID']?.toString();
        final userPhone = actionDetails['phone']?.toString();
        final token = actionDetails['token']?.toString();
        final version = actionDetails['version']?.toString();
        final authMethod = actionDetails['authMethod']?.toString();
        final otpVerified = actionDetails['otpVerified'] as bool? ?? false;

        if (memberId == null || userPhone == null || token == null) {
          return const Left(InfrastructureFailure(
              'Missing required user fields in response'));
        }

        // Check if this is a phone-only v2 login
        if (version == 'v2' && authMethod == 'phone_only') {
          // Create user with minimal info for password setup flow
        final user = User(
          memberId: memberId,
          phone: userPhone,
          token: token,
          otpVerified: otpVerified,
          version: version,
          authMethod: authMethod,
          passwordHash: passwordHash,
          passwordChanged: password != null ? DateTime.now() : null,
        );
        
        // Save user with password info to database
        await _databaseHelper.saveUser(user);
        
        return Right(user);
        }

        // Otherwise process as normal login with dashboard
        // Extract vendor status from dashboard data
        final bool isVendor = dashboardData['member']['activateMarket'] as bool? ?? false;
        Logger.data('[LOGIN_V2] Vendor status from API: $isVendor');
        
        // Parse dashboard data including accountsInternal
        final Map<String, dynamic> dashboardMap = {
          'member': {
            'memberID': actionDetails['memberID'],
            'memberTier': dashboardData['member']['memberTier'],
            'firstname': dashboardData['member']['firstname'],
            'lastname': dashboardData['member']['lastname'],
            'memberHandle': dashboardData['member']['memberHandle'] as String?,
            'defaultDenom': dashboardData['member']['defaultDenom'],
            'profilePictureThumbnail': dashboardData['member']['profilePictureThumbnail'] as String?,
          },
          'accounts': dashboardData['accounts']
              .map((accountData) => {
                    'accountID': accountData['accountID'],
                    'accountName': accountData['accountName'],
                    'accountHandle': accountData['accountHandle'],
                    'defaultDenom': accountData['defaultDenom'],
                    'isOwnedAccount': accountData['isOwnedAccount'],
                    'accountType': accountData['accountType'], // Include accountType field
                    'balanceData': {
                      'securedNetBalancesByDenom': accountData['balanceData']
                          ['securedNetBalancesByDenom'],
                      'unsecuredBalancesInDefaultDenom':
                          _calculateUnsecuredBalances(
                        baseBalances: accountData['balanceData']
                            ['unsecuredBalancesInDefaultDenom'],
                        pendingIn: accountData['pendingInData'] ?? [],
                        pendingOut: accountData['pendingOutData'] ?? [],
                        defaultDenom: accountData['defaultDenom'],
                      ),
                      'netCredexAssetsInDefaultDenom':
                          accountData['balanceData']
                              ['netCredexAssetsInDefaultDenom'],
                    },
                    'pendingInData': {
                      'success': true,
                      'data': accountData['pendingInData'] ?? [],
                      'message': 'Pending offers retrieved',
                    },
                    'pendingOutData': {
                      'success': true,
                      'data': accountData['pendingOutData'] ?? [],
                      'message': 'Pending outgoing offers retrieved',
                    },
                    'sendOffersTo': accountData['sendOffersTo'],
                  })
              .toList(),
        };
        
        // Add accountsInternal if present in the response
        if (dashboardData.containsKey('accountsInternal') && dashboardData['accountsInternal'] != null) {
          Logger.data('[LOGIN_V2] Found accountsInternal in dashboard data');
          dashboardMap['accountsInternal'] = dashboardData['accountsInternal'];
        } else {
          Logger.data('[LOGIN_V2] No accountsInternal found in dashboard data');
        }
        
        final dashboardObj = dashboard.Dashboard.fromMap(dashboardMap);

        // Get existing user to preserve store status and location
        final existingUser = await _databaseHelper.getUser();
        
        final user = User(
          memberId: memberId,
          phone: userPhone,
          token: token,
          otpVerified: otpVerified,
          version: version,
          authMethod: authMethod,
          passwordHash: passwordHash,
          passwordChanged: password != null ? DateTime.now() : null,
          dashboard: dashboardObj,
          activateMarket: isVendor, // Set activateMarket based on vendor status
          // Preserve store status and location from existing user if available
          storeOpen: existingUser?.storeOpen ?? false,
          latitude: existingUser?.latitude,
          longitude: existingUser?.longitude,
        );

        // Save user with password info to database
        await _databaseHelper.saveUser(user);
        
        Logger.data('[LOGIN_V2] Preserved store status: ${user.storeOpen}');
        if (user.latitude != null && user.longitude != null) {
          Logger.data('[LOGIN_V2] Preserved location: (${user.latitude}, ${user.longitude})');
        }

        return Right(user);
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Login failed';
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      final userFriendlyMessage = ErrorTranslator.translateError(e);
      Logger.error('Error in loginV2', e);
      return Left(InfrastructureFailure(userFriendlyMessage));
    }
  }

  // For testing
  @visibleForTesting
  static AccountRepositoryImpl createForTesting({
    required PasswordService passwordService,
    DatabaseHelper? databaseHelper,
    http.Client? httpClient,
  }) {
    return AccountRepositoryImpl(
      passwordService: passwordService,
      databaseHelper: databaseHelper,
      httpClient: httpClient,
    );
  }

  Map<String, dynamic> _calculateUnsecuredBalances({
    required Map<String, dynamic> baseBalances,
    required List<dynamic> pendingIn,
    required List<dynamic> pendingOut,
    required String defaultDenom,
  }) {
    // Extract base values, defaulting to 0.00 if not present
    final double baseReceivables = double.tryParse(baseBalances['totalReceivables']
                ?.toString()
                .replaceAll(RegExp(r'[^\d.-]'), '') ??
            '0.00') ??
        0.00;

    final double basePayables = double.tryParse(baseBalances['totalPayables']
                ?.toString()
                .replaceAll(RegExp(r'[^\d.-]'), '') ??
            '0.00') ??
        0.00;

    // Calculate pending amounts
    final double pendingInTotal = pendingIn.fold(0.00, (sum, tx) {
      final amount = double.tryParse(tx['formattedInitialAmount']
                  ?.toString()
                  .replaceAll(RegExp(r'[^\d.-]'), '') ??
              '0.00') ??
          0.00;
      return sum + amount;
    });

    final double pendingOutTotal = pendingOut.fold(0.00, (sum, tx) {
      final amount = double.tryParse(tx['formattedInitialAmount']
                  ?.toString()
                  .replaceAll(RegExp(r'[^\d.-]'), '') ??
              '0.00') ??
          0.00;
      return sum + amount;
    });

    // Add pending amounts to base values
    final totalReceivables = baseReceivables + pendingInTotal;
    final totalPayables = basePayables + pendingOutTotal;
    final netPayRec = totalReceivables - totalPayables;

    // Format values with denomination
    return {
      'totalReceivables':
          '${totalReceivables.toStringAsFixed(2)} $defaultDenom',
      'totalPayables': '${totalPayables.toStringAsFixed(2)} $defaultDenom',
      'netPayRec': '${netPayRec.toStringAsFixed(2)} $defaultDenom',
    };
  }

  Map<String, String> get _baseHeaders => {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
      };

  Map<String, String> _authHeaders(String token) => {
        ..._baseHeaders,
        'Authorization': 'Bearer $token',
      };

  Future<Either<Failure, T>> _executeAuthenticatedRequest<T>({
    required Future<Either<Failure, T>> Function(String token) request,
    bool isRetry = false,
  }) async {
    try {
      final user = await _databaseHelper.getUser();
      if (user == null) {
        return const Left(InfrastructureFailure('Not authenticated'));
      }

      final result = await request(user.token);

      return result.fold(
        (failure) async {
          if (!isRetry &&
              failure.message?.toLowerCase().contains('token expired') ==
                  true) {
      if (user.passwordHash == null) {
        return const Left(InfrastructureFailure(
            'Authentication failed: No stored password hash'));
      }

            // Re-login with stored password hash
            final loginResult = await loginV2(
              phone: user.phone,
              passwordHash: user.passwordHash,
            );

            return loginResult.fold(
              (loginFailure) => Left(loginFailure),
              (newUser) async {
                Logger.data('[TOKEN_REFRESH] Creating updated user with refreshed token');
                Logger.data('[TOKEN_REFRESH] Original user activateMarket: ${user.activateMarket}');
                Logger.data('[TOKEN_REFRESH] New user activateMarket: ${newUser.activateMarket}');
                
                // Extract vendor status directly from the login response
                bool isVendor = false;
                
                // Get the raw login response to extract vendor status
                try {
                  // We need to access the raw login response to get the vendor status
                  // This is similar to how it's done in the loginV2 method
                  final loginResponse = await loginV2(
                    phone: user.phone,
                    passwordHash: user.passwordHash,
                  );
                  
                  // Extract vendor status from the login response
                  loginResponse.fold(
                    (failure) {
                      Logger.error('[TOKEN_REFRESH] Failed to get vendor status from login response', failure);
                    },
                    (refreshedUser) {
                      isVendor = refreshedUser.activateMarket;
                      Logger.data('[TOKEN_REFRESH] Extracted vendor status from login response: $isVendor');
                    }
                  );
                } catch (e) {
                  Logger.error('[TOKEN_REFRESH] Error extracting vendor status from login response', e);
                }
                
                // Use the extracted vendor status or fall back to previous values
                final activateMarket = isVendor || newUser.activateMarket || user.activateMarket;
                Logger.data('[TOKEN_REFRESH] Final activateMarket value: $activateMarket');
                
                final userWithPasswordHash = User(
                  memberId: newUser.memberId,
                  phone: newUser.phone,
                  token: newUser.token,
                  passwordHash: user.passwordHash,
                  passwordChanged: user.passwordChanged,
                  dashboard: newUser.dashboard,
                  activateMarket: activateMarket, // Set vendor status based on dashboard data
                  storeOpen: user.storeOpen, // Preserve the original storeOpen status
                  latitude: user.latitude, // Preserve the original latitude
                  longitude: user.longitude, // Preserve the original longitude
                  version: newUser.version,
                  authMethod: newUser.authMethod,
                  otpVerified: newUser.otpVerified,
                );

                Logger.data('[TOKEN_REFRESH] Updated user activateMarket: ${userWithPasswordHash.activateMarket}');
                final saveResult = await saveUser(userWithPasswordHash);

                return saveResult.fold(
                  (saveFailure) => Left(saveFailure),
                  (_) => _executeAuthenticatedRequest<T>(
                    request: request,
                    isRetry: true,
                  ),
                );
              },
            );
          }
          return Left(failure);
        },
        Right.new,
      );
    } catch (e) {
      final userFriendlyMessage = ErrorTranslator.translateError(e);
      Logger.error('Error in _executeAuthenticatedRequest', e);
      return Left(InfrastructureFailure(userFriendlyMessage));
    }
  }

  Future<http.Response> _loggedRequest(
    Future<http.Response> Function() request,
    String url,
    String method, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      NetworkLogger.logRequest(
        url: url,
        method: method,
        headers: headers ?? {},
        body: body,
      );

      final response = await request();

      NetworkLogger.logResponse(
        url: url,
        statusCode: response.statusCode,
        body: response.body,
      );

      return response;
    } catch (e) {
      NetworkLogger.logError(url: url, error: e);
      rethrow;
    }
  }

  @override
  Future<Either<Failure, List<LedgerEntry>>> getLedger({
    required String accountId,
    DateTime? afterTimestamp,
    int? limit,
  }) async {
    try {
      // Check if we have any cached entries
      final hasCachedEntries = await _databaseHelper.hasLedgerEntries(accountId);
      final cachedEntries = await _databaseHelper.getLedgerEntries(accountId);
      
      // If no afterTimestamp provided and we have cached entries, return from cache
      if (afterTimestamp == null && hasCachedEntries) {
        Logger.data('Returning ${cachedEntries.length} cached ledger entries');
        return Right(cachedEntries);
      }

      // Get latest timestamp from cache if not provided and we have cached entries
      final latestTimestamp = afterTimestamp ?? (hasCachedEntries ? await _databaseHelper.getLatestLedgerTimestamp(accountId) : null);
      
      // Fetch from API
      return _executeAuthenticatedRequest(
        request: (token) async {
          final url = '$baseUrl/getLedger';
          final headers = _authHeaders(token);
          final body = {
            'accountID': accountId,
            if (latestTimestamp != null) 'afterTimestamp': latestTimestamp.toIso8601String(),
            if (limit != null || !hasCachedEntries) 'numRows': limit ?? 1000, // Load all entries if cache is empty
          };

          final response = await _loggedRequest(
            () => _httpClient.post(
              Uri.parse(url),
              headers: headers,
              body: json.encode(body),
            ),
            url,
            'POST',
            headers: headers,
            body: body,
          );

          if (response.statusCode == 429) {
            throw RateLimitException(json.decode(response.body));
          } else if (response.statusCode == 200) {
            final jsonResponse = json.decode(response.body);
            if (!jsonResponse.containsKey('data') || 
                !jsonResponse['data'].containsKey('dashboard') ||
                !jsonResponse['data']['dashboard'].containsKey('ledger')) {
              return const Left(InfrastructureFailure('Invalid response format'));
            }

            final ledgerData = jsonResponse['data']['dashboard']['ledger'] as List;
            final newEntries = ledgerData.map((entry) {
              try {
                return LedgerEntry.fromJson(
                  entry as Map<String, dynamic>,
                  accountId: accountId,
                  accountName: entry['accountName'] ?? '',
                );
              } catch (e) {
                Logger.error('Error parsing ledger entry', e);
                return null;
              }
            }).whereType<LedgerEntry>().toList();

            // Save new entries to database
            if (newEntries.isNotEmpty) {
              await _databaseHelper.saveLedgerEntries(newEntries, accountId);
              Logger.data('Saved ${newEntries.length} new ledger entries to database');
            }

            // If this was an incremental update, combine with cached entries
            if (latestTimestamp != null) {
              final allEntries = [...cachedEntries, ...newEntries];
              allEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return Right(allEntries);
            }

            return Right(newEntries);
          } else {
            final errorMessage = json.decode(response.body)['message'] ?? 'Failed to get ledger';
            return Left(InfrastructureFailure(errorMessage));
          }
        },
      );
    } catch (e) {
      Logger.error('Error in getLedger', e);
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getLedgerLegacy({
    required String accountId,
    int? startRow,
    int? numRows,
  }) async {
    return _executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/getLedger';
        final headers = _authHeaders(token);
        final body = {
          'accountID': accountId,
          if (startRow != null) 'startRow': startRow,
          if (numRows != null) 'numRows': numRows,
        };

        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          ),
          url,
          'POST',
          headers: headers,
          body: body,
        );

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          return Right(jsonResponse);
        } else {
          final errorMessage =
              json.decode(response.body)['message'] ?? 'Failed to get ledger';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final user = await _databaseHelper.getUser();
      return Right(user);
    } catch (e) {
      final userFriendlyMessage = ErrorTranslator.translateError(e);
      Logger.error('Error in login', e);
      return Left(InfrastructureFailure(userFriendlyMessage));
    }
  }

  @override
  Future<Either<Failure, bool>> saveUser(User user) async {
    try {
      await _databaseHelper.saveUser(user);
      return const Right(true);
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, double>>> getBalances() async {
    return _executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/balances';
        final headers = _authHeaders(token);

        final response = await _loggedRequest(
          () => _httpClient.get(Uri.parse(url), headers: headers),
          url,
          'GET',
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return Right(Map<String, double>.from(data['balances']));
        } else {
          final errorMessage =
              json.decode(response.body)['message'] ?? 'Failed to get balances';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }

  @override
  Future<Either<Failure, Account>> getAccountByHandle(String handle) async {
    return _executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/getAccountByHandle';
        final headers = _authHeaders(token);
        final body = {'accountHandle': handle};

        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          ),
          url,
          'POST',
          headers: headers,
          body: body,
        );

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);

          if (!jsonResponse.containsKey('data') ||
              !jsonResponse['data'].containsKey('action') ||
              !jsonResponse['data']['action'].containsKey('details')) {
            return const Left(InfrastructureFailure('Invalid response format'));
          }

          final details = jsonResponse['data']['action']['details'];

          return Right(Account(
            id: details['accountID'],
            handle: details['accountHandle'],
            name: details['accountName'],
            defaultDenom: details['defaultDenom'],
            balances: {},
          ));
        } else {
          final errorMessage =
              json.decode(response.body)['message'] ?? 'Failed to get account';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }

  @override
  Future<Either<Failure, bool>> onboardMember({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
  }) async {
    try {
      // Hash password before sending to server
      final hash = await _passwordService.hashPassword(password);

      // Format phone number before sending
      final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      Logger.data('[ONBOARD_MEMBER] Formatted phone number: $formattedPhone');

      final url = '$baseUrl/onboardMember';
      final body = {
        'firstname': firstName,
        'lastname': lastName,
        'phone': formattedPhone,
        'defaultDenom': 'USD',
        'password': hash,
      };

      final response = await _loggedRequest(
        () => _httpClient.post(
          Uri.parse(url),
          headers: _baseHeaders,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: _baseHeaders,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return const Right(true);
      } else {
        final errorMessage =
            json.decode(response.body)['message'] ?? 'Failed to onboard member';
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  Map<String, String>? _extractTokenInfo(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final data = json.decode(decoded);

      return {
        'version': data['version']?.toString() ?? 'v1',
        'authMethod': data['authMethod']?.toString() ?? 'password',
      };
    } catch (e) {
      Logger.error('Error decoding token', e);
      return null;
    }
  }

  @override
  Future<Either<Failure, User>> login({
    required String phone,
    String? password,
    String? passwordHash,
  }) async {
    try {
      // Format phone number before sending
      final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      Logger.data('[LOGIN] Formatted phone number: $formattedPhone');

      final url = '$baseUrl/login';
      final body = {
        'phone': formattedPhone,
      };

      // For phone-only authentication, we don't send any password fields
      if (passwordHash != null) {
        // Only include password fields for token refresh
        body['password_hash'] = passwordHash;
      }


      final response = await _loggedRequest(
        () => _httpClient.post(
          Uri.parse(url),
          headers: _baseHeaders,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: _baseHeaders,
        body: body,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (!jsonResponse.containsKey('data') ||
            !jsonResponse['data'].containsKey('action') ||
            !jsonResponse['data']['action'].containsKey('details') ||
            !jsonResponse['data'].containsKey('dashboard')) {
          return const Left(InfrastructureFailure('Invalid response format'));
        }

        final actionDetails = jsonResponse['data']['action']['details'];

        final memberId = actionDetails['memberID']?.toString();
        final userPhone = actionDetails['phone']?.toString();
        final token = actionDetails['token']?.toString();

        if (memberId == null || userPhone == null || token == null) {
          return const Left(InfrastructureFailure(
              'Missing required user fields in response'));
        }

        final dashboardData = jsonResponse['data']['dashboard'];

        // Extract vendor status from dashboard data
        final bool isVendor = dashboardData['member']['activateMarket'] as bool? ?? false;
        Logger.data('[LOGIN] Vendor status from API: $isVendor');
        
        // Extract profile thumbnail URL from dashboard data
        final String? profileThumbnailUrl = dashboardData['member']['profilePictureThumbnail'] as String?;
        Logger.data('[LOGIN] Profile thumbnail URL: $profileThumbnailUrl');
        
        // Parse dashboard data including accountsInternal
        final Map<String, dynamic> dashboardMap = {
          'member': {
            'memberID': actionDetails['memberID'],
            'memberTier': dashboardData['member']['memberTier'],
            'firstname': dashboardData['member']['firstname'],
            'lastname': dashboardData['member']['lastname'],
            'memberHandle': dashboardData['member']['memberHandle'] as String?,
            'defaultDenom': dashboardData['member']['defaultDenom'],
            'profilePictureThumbnail': profileThumbnailUrl,
          },
          'accounts': dashboardData['accounts']
              .map((accountData) => {
                    'accountID': accountData['accountID'],
                    'accountName': accountData['accountName'],
                    'accountHandle': accountData['accountHandle'],
                    'defaultDenom': accountData['defaultDenom'],
                    'isOwnedAccount': accountData['isOwnedAccount'],
                    'balanceData': {
                      'securedNetBalancesByDenom': accountData['balanceData']
                          ['securedNetBalancesByDenom'],
                      'unsecuredBalancesInDefaultDenom':
                          _calculateUnsecuredBalances(
                        baseBalances: accountData['balanceData']
                            ['unsecuredBalancesInDefaultDenom'],
                        pendingIn: accountData['pendingInData'] ?? [],
                        pendingOut: accountData['pendingOutData'] ?? [],
                        defaultDenom: accountData['defaultDenom'],
                      ),
                      'netCredexAssetsInDefaultDenom':
                          accountData['balanceData']
                              ['netCredexAssetsInDefaultDenom'],
                    },
                    'pendingInData': {
                      'success': true,
                      'data': accountData['pendingInData'] ?? [],
                      'message': 'Pending offers retrieved',
                    },
                    'pendingOutData': {
                      'success': true,
                      'data': accountData['pendingOutData'] ?? [],
                      'message': 'Pending outgoing offers retrieved',
                    },
                    'sendOffersTo': accountData['sendOffersTo'],
                  })
              .toList(),
        };
        
        // Add accountsInternal if present in the response
        if (dashboardData.containsKey('accountsInternal') && dashboardData['accountsInternal'] != null) {
          Logger.data('[LOGIN] Found accountsInternal in dashboard data');
          dashboardMap['accountsInternal'] = dashboardData['accountsInternal'];
        } else {
          Logger.data('[LOGIN] No accountsInternal found in dashboard data');
        }
        
        final dashboardObj = dashboard.Dashboard.fromMap(dashboardMap);

        // Extract version and authMethod from token
        final tokenInfo = _extractTokenInfo(token);
        final version = tokenInfo?['version'] ?? 'v1';
        final authMethod = tokenInfo?['authMethod'] ?? 'password';

        // For v1 phone-only auth, return minimal user info
        if (version == 'v1' && authMethod == 'phone_only') {
          final user = User(
            memberId: memberId,
            phone: userPhone,
            token: token,
            otpVerified: false,
            version: version,
            authMethod: authMethod,
          );
          return Right(user);
        }

        // Get existing user to preserve store status and location
        final existingUser = await _databaseHelper.getUser();
        
        // Otherwise return full user info
        final user = User(
          memberId: memberId,
          phone: userPhone,
          token: token,
          passwordHash: body['password_hash'],
          passwordChanged: DateTime.now(),
          version: version,
          authMethod: authMethod,
          dashboard: dashboardObj,
          activateMarket: isVendor, // Set activateMarket based on vendor status
          // Preserve store status and location from existing user if available
          storeOpen: existingUser?.storeOpen ?? false,
          latitude: existingUser?.latitude,
          longitude: existingUser?.longitude,
        );
        
        Logger.data('[LOGIN] Preserved store status: ${user.storeOpen}');
        if (user.latitude != null && user.longitude != null) {
          Logger.data('[LOGIN] Preserved location: (${user.latitude}, ${user.longitude})');
        }

        return Right(user);
      } else {
        final errorMessage =
            json.decode(response.body)['message'] ?? 'Login failed';
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, credex.CredexResponse>> createCredex(
      CredexRequest request) async {
    Logger.data('Creating Credex request: ${request.toJson()}');

    return _executeAuthenticatedRequest(
      request: (token) async {
        try {
          final url = '$baseUrl/createCredex';
          final headers = _authHeaders(token);
          final body = request.toJson();

          Logger.data('Sending Credex request to $url');
          final response = await _loggedRequest(
            () => _httpClient.post(
              Uri.parse(url),
              headers: headers,
              body: json.encode(body),
            ),
            url,
            'POST',
            headers: headers,
            body: body,
          );

          if (response.statusCode == 200) {
            Logger.data('Credex request successful');
            final jsonResponse = json.decode(response.body);

            // Validate response structure
            if (!jsonResponse.containsKey('data')) {
              Logger.error('Invalid Credex response: Missing data field');
              return const Left(InfrastructureFailure(
                  'Invalid response format: Missing data field'));
            }

            final data = jsonResponse['data'];
            if (!data.containsKey('action') || !data.containsKey('dashboard')) {
              Logger.error(
                  'Invalid Credex response: Missing required fields in data');
              return const Left(InfrastructureFailure(
                  'Invalid response format: Missing required fields'));
            }

            final action = data['action'];
            final dashboard = data['dashboard'];

            if (dashboard == null) {
              Logger.error('Invalid Credex response: Missing dashboard');
              return const Left(InfrastructureFailure(
                  'Invalid response format: Missing dashboard'));
            }
            Logger.data('Creating CredexResponse from data');
            return Right(credex.CredexResponse(
              message: jsonResponse['message'],
              data: credex.CredexData(
                action: credex.CredexAction(
                  id: action['id'],
                  type: action['type'],
                  timestamp: action['timestamp'],
                  actor: action['actor'],
                  details: credex.CredexActionDetails(
                    amount: action['details']['amount'],
                    denomination: action['details']['denomination'],
                    securedCredex: action['details']['securedCredex'],
                    receiverAccountID: action['details']['receiverAccountID'],
                    receiverAccountName: action['details']
                        ['receiverAccountName'],
                  ),
                ),
                dashboard: credex.CredexDashboard(
                  member: credex.DashboardMember(
                    memberID: dashboard['member']['memberID'],
                    memberTier: dashboard['member']['memberTier'],
                    firstname: dashboard['member']['firstname'],
                    lastname: dashboard['member']['lastname'],
                    memberHandle: dashboard['member']['memberHandle'],
                    defaultDenom: dashboard['member']['defaultDenom'],
                  ),
                  accounts: List<credex.DashboardAccount>.from(
                    (dashboard['accounts'] as List).map((account) =>
                        credex.DashboardAccount(
                          accountID: account['accountID'],
                          accountName: account['accountName'],
                          accountHandle: account['accountHandle'],
                          accountType: account['accountType'],
                          defaultDenom: account['defaultDenom'],
                          isOwnedAccount: account['isOwnedAccount'],
                          sendOffersTo: credex.SendOffersTo(
                            memberID: account['sendOffersTo']['memberID'],
                            firstname: account['sendOffersTo']['firstname'],
                            lastname: account['sendOffersTo']['lastname'],
                          ),
                          balanceData: credex.BalanceData.fromMap(account),
                          pendingInData: List<credex.PendingOffer>.from(
                            (account['pendingInData'] as List? ?? []).map(
                                (offer) => credex.PendingOffer.fromMap(offer)),
                          ),
                          pendingOutData: List<credex.PendingOffer>.from(
                            (account['pendingOutData'] as List? ?? []).map(
                                (offer) => credex.PendingOffer.fromMap(offer)),
                          ),
                        )),
                  ),
                ),
              ),
            ));
          } else {
            Logger.error('Failed to create Credex',
                'Status ${response.statusCode}: ${response.body}');
            return Left(InfrastructureFailure(response.body));
          }
        } catch (e, stackTrace) {
          Logger.error('Error creating Credex', e, stackTrace);
          return Left(InfrastructureFailure(
              'Unexpected error while creating Credex: ${e.toString()}'));
        }
      },
    );
  }

  @override
  Future<Either<Failure, bool>> acceptCredexBulk(List<String> credexIds) async {
    return _executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/acceptCredexBulk';
        final headers = _authHeaders(token);
        final body = {'credexIDs': credexIds};

        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          ),
          url,
          'POST',
          headers: headers,
          body: body,
        );

        if (response.statusCode == 200) {
          return const Right(true);
        } else {
          final errorMessage = json.decode(response.body)['message'] ??
              'Failed to accept Credex transactions';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }

  @override
  Future<Either<Failure, bool>> acceptCredex(String credexId) async {
    return _executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/acceptCredex';
        final headers = _authHeaders(token);
        final body = {'credexID': credexId};

        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          ),
          url,
          'POST',
          headers: headers,
          body: body,
        );

        if (response.statusCode == 200) {
          return const Right(true);
        } else {
          final errorMessage = json.decode(response.body)['message'] ??
              'Failed to accept Credex transaction';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }

  @override
  Future<Either<Failure, bool>> cancelCredex(String credexId) async {
    return _executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/cancelCredex';
        final headers = _authHeaders(token);
        final body = {'credexID': credexId};

        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          ),
          url,
          'POST',
          headers: headers,
          body: body,
        );

        if (response.statusCode == 200) {
          return const Right(true);
        } else {
          final errorMessage = json.decode(response.body)['message'] ??
              'Failed to cancel Credex transaction';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }

  @override
  Future<Either<Failure, bool>> registerNotificationToken(String token) async {
    return _executeAuthenticatedRequest(
      request: (authToken) async {
        final url = '$baseUrl/api/notifications/register-token';
        final headers = _authHeaders(authToken);
        final body = {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android'
        };

        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          ),
          url,
          'POST',
          headers: headers,
          body: body,
        );

        if (response.statusCode == 200) {
          return const Right(true);
        } else {
          final errorMessage = json.decode(response.body)['message'] ??
              'Failed to register notification token';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    try {
      final sanitizedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      final url = '$baseUrl/verify/requestOtp';
      final body = {
        'phone': sanitizedPhone,
        'purpose': purpose,
      };

      Logger.data('[REQUEST_OTP] Sending request for phone: $sanitizedPhone, purpose: $purpose');
      final response = await _loggedRequest(
        () => _httpClient.post(
          Uri.parse(url),
          headers: _baseHeaders,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: _baseHeaders,
        body: body,
      );

      if (response.statusCode == 200) {
        Logger.data('[REQUEST_OTP] Request successful');
        final jsonResponse = json.decode(response.body);
        return Right(jsonResponse);
      } else {
        final responseBody = json.decode(response.body);
        final errorMessage = responseBody['message'] ?? 'Failed to request OTP';
        
        // Extract error code if available
        String? errorCode;
        if (responseBody.containsKey('data') && 
            responseBody['data'].containsKey('action') &&
            responseBody['data']['action'].containsKey('details')) {
          errorCode = responseBody['data']['action']['details']['code'];
          final reason = responseBody['data']['action']['details']['reason'];
          Logger.error('[REQUEST_OTP] Request failed with code: $errorCode', 'Reason: $reason');
        } else {
          Logger.error('[REQUEST_OTP] Request failed', errorMessage);
        }
        
        return Left(InfrastructureFailure(errorMessage, errorCode));
      }
    } catch (e) {
      Logger.error('[REQUEST_OTP] Exception occurred', e);
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OtpVerificationResponse>> verifyOtp({
    required String token,
    required String otp,
    required String purpose,
    String? memberId,
  }) async {
    try {
      final url = '$baseUrl/verify/verifyOtp';
      final headers = _authHeaders(token);
      final body = {
        'otp': otp,
        'purpose': purpose,
      };

      // Only include memberId if provided
      if (memberId != null) {
        body['memberID'] = memberId;
      }

      Logger.data('[VERIFY_OTP] Sending request...');
      final response = await _loggedRequest(
        () => _httpClient.post(
          Uri.parse(url),
          headers: headers,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: headers,
        body: body,
      );

      Logger.data('''
[VERIFY_OTP] Response received:
Status code: ${response.statusCode}
Response body: ${response.body}
''');

      if (response.statusCode == 200) {
        Logger.data('[VERIFY_OTP] Request successful, parsing response');
        final jsonResponse = json.decode(response.body);
        return Right(OtpVerificationResponse.fromJson(jsonResponse));
      } else {
        final responseBody = json.decode(response.body);
        final errorMessage = responseBody['message'] ?? 'Failed to verify OTP';
        
        // Extract error code if available
        String? errorCode;
        if (responseBody.containsKey('data') && 
            responseBody['data'].containsKey('action') &&
            responseBody['data']['action'].containsKey('details')) {
          errorCode = responseBody['data']['action']['details']['code'];
          final reason = responseBody['data']['action']['details']['reason'];
          Logger.error('[VERIFY_OTP] Request failed with code: $errorCode', 'Reason: $reason');
        } else {
          Logger.error('[VERIFY_OTP] Request failed', errorMessage);
        }
        
        return Left(InfrastructureFailure(errorMessage, errorCode));
      }
    } catch (e) {
      Logger.error('[VERIFY_OTP] Exception occurred', e);
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> setInitialPassword({
    required String token,
    required String memberId,
    required String phone,
    required String password,
  }) async {
    try {
      Logger.data('[SET_INITIAL_PASSWORD] Starting password setup');
      
      final url = '$baseUrl/setInitialPassword';
      final headers = _authHeaders(token);
      
      // Format phone number
      final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      
      // Hash password and prepare body
      final hashedPassword = await _passwordService.hashPassword(password);
      final body = {
        'phone': formattedPhone,
        'password': hashedPassword,
        'memberID': memberId,
      };

      Logger.data('''
[SET_INITIAL_PASSWORD] Request details:
URL: $url
Headers: ${headers.map((k, v) => MapEntry(k, k == 'Authorization' ? 'Bearer [REDACTED]' : v))}
Request body (redacted):
${{'phone': formattedPhone, 'password': '[REDACTED]', 'memberID': memberId}}
Using token from v1 login: ${token.substring(0, 10)}...
''');
      final response = await _loggedRequest(
        () => _httpClient.post(
          Uri.parse(url),
          headers: headers,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: headers,
        body: body,
      );

      Logger.data('''
[SET_INITIAL_PASSWORD] Response received:
Status code: ${response.statusCode}
Response body: ${response.body}
''');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        Logger.data('[SET_INITIAL_PASSWORD] Response parsed successfully');
        
        if (!jsonResponse.containsKey('data')) {
          Logger.error('[SET_INITIAL_PASSWORD] Invalid response format: Missing data field');
          return const Left(InfrastructureFailure('Invalid response format: Missing data field'));
        }
        
        if (!jsonResponse['data'].containsKey('action')) {
          Logger.error('[SET_INITIAL_PASSWORD] Invalid response format: Missing action field');
          return const Left(InfrastructureFailure('Invalid response format: Missing action field'));
        }
        
        if (!jsonResponse['data']['action'].containsKey('details')) {
          Logger.error('[SET_INITIAL_PASSWORD] Invalid response format: Missing details field');
          return const Left(InfrastructureFailure('Invalid response format: Missing details field'));
        }

        final actionDetails = jsonResponse['data']['action']['details'];
        final memberId = actionDetails['memberID']?.toString();
        final userPhone = actionDetails['phone']?.toString();
        final token = actionDetails['token']?.toString();

        if (memberId == null || userPhone == null || token == null) {
          return const Left(InfrastructureFailure('Missing required user fields in response'));
        }

        Logger.data('[SET_INITIAL_PASSWORD] Password set successfully, proceeding with v2 login');
        
        // Get existing user to preserve store status and location
        final existingUser = await _databaseHelper.getUser();
        
        // Immediately perform v2 login with the new password hash
        final loginResult = await loginV2(
          phone: formattedPhone,
          passwordHash: hashedPassword,
        );
        
        // If we have an existing user and the login was successful, ensure we preserve the store status and location
        if (existingUser != null) {
          return loginResult.fold(
            (failure) => Left(failure),
            (newUser) async {
              // Create updated user with preserved store status and location
              final updatedUser = newUser.copyWith(
                storeOpen: existingUser.storeOpen,
                latitude: existingUser.latitude,
                longitude: existingUser.longitude,
              );
              
              // Save the updated user
              await _databaseHelper.saveUser(updatedUser);
              
              Logger.data('[SET_INITIAL_PASSWORD] Preserved store status: ${updatedUser.storeOpen}');
              if (updatedUser.latitude != null && updatedUser.longitude != null) {
                Logger.data('[SET_INITIAL_PASSWORD] Preserved location: (${updatedUser.latitude}, ${updatedUser.longitude})');
              }
              
              return Right(updatedUser);
            },
          );
        }
        
        return loginResult;
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Failed to set initial password';
        Logger.error('Failed to set initial password', errorMessage);
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      Logger.error('Error setting initial password', e);
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return _executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/updatePassword';
        final headers = _authHeaders(token);

        // Get current user to verify password hash
        final user = await _databaseHelper.getUser();
        if (user == null) {
          return const Left(InfrastructureFailure('Not authenticated'));
        }

        // Hash both passwords
        final currentHash = await _passwordService.hashPassword(currentPassword);
        final newHash = await _passwordService.hashPassword(newPassword);

        // Verify current password matches stored hash
        if (user.passwordHash != null && currentHash != user.passwordHash) {
          return const Left(AuthFailure(
            message: 'Current password is incorrect',
            code: 'INVALID_PASSWORD',
          ));
        }

        final body = {
          'currentPassword': currentHash,
          'newPassword': newHash,
        };

        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          ),
          url,
          'POST',
          headers: headers,
          body: body,
        );

        if (response.statusCode == 200) {
          // Update stored password hash while preserving store status and location
          final updatedUser = user.copyWith(
            passwordHash: newHash,
            passwordChanged: DateTime.now(),
            // No need to explicitly set storeOpen, latitude, and longitude
            // as copyWith will preserve them from the original user object
          );
          
          Logger.data('[UPDATE_PASSWORD] Preserved store status: ${updatedUser.storeOpen}');
          if (updatedUser.latitude != null && updatedUser.longitude != null) {
            Logger.data('[UPDATE_PASSWORD] Preserved location: (${updatedUser.latitude}, ${updatedUser.longitude})');
          }
          await _databaseHelper.saveUser(updatedUser);
          
          return const Right(true);
        } else {
          final errorMessage = json.decode(response.body)['message'] ?? 'Failed to update password';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }

@override
Future<bool> resetPassword({
  required String resetToken,
  required String newPassword,
}) async {
  try {
    final url = '$baseUrl/resetPassword';
    final headers = _baseHeaders;

    // Hash the new password before sending
    final hashedPassword = await _passwordService.hashPassword(newPassword);
    
    final body = {
      'resetToken': resetToken,
      'newPassword': hashedPassword,
    };

    final response = await _loggedRequest(
      () => _httpClient.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      ),
      url,
      'POST',
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      Logger.data('[RESET_PASSWORD] Password reset successful');
      return true;
    } else {
      final errorMessage = json.decode(response.body)['message'] ?? 'Failed to reset password';
      return false;
    }
  } catch (e) {
    Logger.error('Error resetting password', e);
    return false;
  }
}

@override
Future<Either<Failure, bool>> upgradeToHustler10k(String accountId) async {
  Logger.data('[UPGRADE_TO_HUSTLER10K] Starting upgrade for account: $accountId');
  
  return _executeAuthenticatedRequest(
    request: (token) async {
      try {
        final url = '$baseUrl/hustler10k';
        final headers = _authHeaders(token);
        final body = {'personalAccountID': accountId};

        Logger.data('[UPGRADE_TO_HUSTLER10K] Sending request to $url');
        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          ),
          url,
          'POST',
          headers: headers,
          body: body,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          Logger.data('[UPGRADE_TO_HUSTLER10K] Upgrade successful');
          return const Right(true);
        } else {
          final responseBody = json.decode(response.body);
          final errorMessage = responseBody['message'] ?? 'Failed to upgrade to Hustler10k';
          
          // Extract error code if available
          String? errorCode;
          if (responseBody.containsKey('data') && 
              responseBody['data'].containsKey('action') &&
              responseBody['data']['action'].containsKey('details')) {
            errorCode = responseBody['data']['action']['details']['code'];
            Logger.error('[UPGRADE_TO_HUSTLER10K] Upgrade failed with code: $errorCode', errorMessage);
          } else {
            Logger.error('[UPGRADE_TO_HUSTLER10K] Upgrade failed', errorMessage);
          }
          
          return Left(InfrastructureFailure(errorMessage, errorCode));
        }
      } catch (e, stackTrace) {
        Logger.error('[UPGRADE_TO_HUSTLER10K] Error during upgrade', e, stackTrace);
        return Left(InfrastructureFailure(
            'Unexpected error during upgrade: ${e.toString()}'));
      }
    },
  );
}

  Future<Either<Failure, RecurringResponse>> createRecurring(
      RecurringRequest request) async {
    Logger.data('Creating Recurring request: ${request.toJson()}');

    return _executeAuthenticatedRequest(
      request: (token) async {
        try {
          final url = '$baseUrl/createRecurring';
          final headers = _authHeaders(token);
          final body = request.toJson();

          Logger.data('Sending Recurring request to $url');
          final response = await _loggedRequest(
            () => _httpClient.post(
              Uri.parse(url),
              headers: headers,
              body: json.encode(body),
            ),
            url,
            'POST',
            headers: headers,
            body: body,
          );

          if (response.statusCode == 201) {
            Logger.data('Recurring request successful');
            final jsonResponse = json.decode(response.body);

            if (!jsonResponse.containsKey('data')) {
              Logger.error('Invalid Recurring response: Missing data field');
              return const Left(InfrastructureFailure(
                  'Invalid response format: Missing data field'));
            }

            final data = jsonResponse['data'];
            if (!data.containsKey('action')) {
              Logger.error('Invalid Recurring response: Missing action field');
              return const Left(InfrastructureFailure(
                  'Invalid response format: Missing action field'));
            }

            final action = data['action'];
            final details = action['details'];
            final nextDateData = details['nextDate'];

            final dashboardData = data['dashboard'];
            if (!dashboardData.containsKey('member') || !dashboardData.containsKey('accounts')) {
              Logger.error('Invalid Recurring response: Missing required dashboard fields');
              return const Left(InfrastructureFailure(
                  'Invalid response format: Missing required dashboard fields'));
            }

            Logger.data('Creating Dashboard from response data');
            // Parse dashboard data including accountsInternal
            // Extract profile thumbnail URL from dashboard data
            final String? profileThumbnailUrl = dashboardData['member']['profilePictureThumbnail'] as String?;
            Logger.data('[RECURRING] Profile thumbnail URL: $profileThumbnailUrl');
            
            final Map<String, dynamic> dashboardMap = {
              'member': {
                'memberID': dashboardData['member']['memberID'],
                'memberTier': dashboardData['member']['memberTier'],
                'firstname': dashboardData['member']['firstname'],
                'lastname': dashboardData['member']['lastname'],
                'memberHandle': dashboardData['member']['memberHandle'] as String? ?? '',
                'defaultDenom': dashboardData['member']['defaultDenom'],
                'profilePictureThumbnail': profileThumbnailUrl,
              },
              'accounts': dashboardData['accounts']
                  .map((accountData) => {
                        'accountID': accountData['accountID'],
                        'accountName': accountData['accountName'],
                        'accountHandle': accountData['accountHandle'],
                        'defaultDenom': accountData['defaultDenom'],
                        'isOwnedAccount': accountData['isOwnedAccount'],
                        'accountType': accountData['accountType'], // Include accountType field
                        'balanceData': {
                          'securedNetBalancesByDenom': accountData['balanceData']
                              ['securedNetBalancesByDenom'],
                          'unsecuredBalancesInDefaultDenom':
                              _calculateUnsecuredBalances(
                            baseBalances: accountData['balanceData']
                                ['unsecuredBalancesInDefaultDenom'],
                            pendingIn: accountData['pendingInData'] ?? [],
                            pendingOut: accountData['pendingOutData'] ?? [],
                            defaultDenom: accountData['defaultDenom'],
                          ),
                          'netCredexAssetsInDefaultDenom':
                              accountData['balanceData']
                                  ['netCredexAssetsInDefaultDenom'],
                        },
                        'pendingInData': {
                          'success': true,
                          'data': accountData['pendingInData'] ?? [],
                          'message': 'Pending offers retrieved',
                        },
                        'pendingOutData': {
                          'success': true,
                          'data': accountData['pendingOutData'] ?? [],
                          'message': 'Pending outgoing offers retrieved',
                        },
                        'sendOffersTo': accountData['sendOffersTo'],
                      })
                  .toList(),
            };
            
            // Add accountsInternal if present in the response
            if (dashboardData.containsKey('accountsInternal') && dashboardData['accountsInternal'] != null) {
              Logger.data('[RECURRING] Found accountsInternal in dashboard data');
              dashboardMap['accountsInternal'] = dashboardData['accountsInternal'];
            } else {
              Logger.data('[RECURRING] No accountsInternal found in dashboard data');
            }
            
            final dashboardObj = dashboard.Dashboard.fromMap(dashboardMap);

            Logger.data('Creating RecurringResponse with parsed dashboard');
            return Right(RecurringResponse(
              message: jsonResponse['message'],
              data: RecurringData(
                action: RecurringAction(
                  id: action['id'],
                  type: action['type'],
                  timestamp: action['timestamp'],
                  actor: action['actor'],
                  details: RecurringActionDetails(
                    recurringID: details['recurringID'],
                    amount: details['amount'],
                    denomination: details['denomination'],
                    payFrequency: details['payFrequency'],
                    nextDate: NextDate(
                      year: YearValue(
                        low: nextDateData['year']['low'],
                        high: nextDateData['year']['high'],
                      ),
                      month: YearValue(
                        low: nextDateData['month']['low'],
                        high: nextDateData['month']['high'],
                      ),
                      day: YearValue(
                        low: nextDateData['day']['low'],
                        high: nextDateData['day']['high'],
                      ),
                    ),
                    status: details['status'],
                  ),
                ),
                dashboard: dashboardObj,
              ),
            ));
          } else {
            Logger.error('Failed to create Recurring',
                'Status ${response.statusCode}: ${response.body}');
            return Left(InfrastructureFailure(response.body));
          }
        } catch (e, stackTrace) {
          Logger.error('Error creating Recurring', e, stackTrace);
          return Left(InfrastructureFailure(
              'Unexpected error while creating Recurring: ${e.toString()}'));
        }
      },
    );
  }
}
