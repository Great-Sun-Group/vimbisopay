import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:dartz/dartz.dart';
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
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/infrastructure/services/password_service.dart';
import 'package:vimbisopay_app/infrastructure/services/network_logger.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';

class AccountRepositoryImpl implements AccountRepository {
  final String baseUrl = ApiConfig.baseUrl;

  DatabaseHelper _databaseHelper = DatabaseHelper();
  SecurityService _securityService = SecurityService();
  PasswordService _passwordService = PasswordService();
  http.Client _httpClient = http.Client();

  // For testing
  set databaseHelper(DatabaseHelper helper) => _databaseHelper = helper;
  set securityService(SecurityService service) => _securityService = service;
  set passwordService(PasswordService service) => _passwordService = service;
  set httpClient(http.Client client) => _httpClient = client;

  Map<String, dynamic> _calculateUnsecuredBalances({
    required Map<String, dynamic> baseBalances,
    required List<dynamic> pendingIn,
    required List<dynamic> pendingOut,
    required String defaultDenom,
  }) {
    // Extract base values, defaulting to 0.00 if not present
    double baseReceivables = double.tryParse(baseBalances['totalReceivables']
                ?.toString()
                .replaceAll(RegExp(r'[^\d.-]'), '') ??
            '0.00') ??
        0.00;

    double basePayables = double.tryParse(baseBalances['totalPayables']
                ?.toString()
                .replaceAll(RegExp(r'[^\d.-]'), '') ??
            '0.00') ??
        0.00;

    // Calculate pending amounts
    double pendingInTotal = pendingIn.fold(0.00, (sum, tx) {
      final amount = double.tryParse(tx['formattedInitialAmount']
                  ?.toString()
                  .replaceAll(RegExp(r'[^\d.-]'), '') ??
              '0.00') ??
          0.00;
      return sum + amount;
    });

    double pendingOutTotal = pendingOut.fold(0.00, (sum, tx) {
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
            if (user.passwordHash == null || user.passwordSalt == null) {
              return const Left(InfrastructureFailure(
                  'Authentication failed: No stored password hash'));
            }

            // Re-login with stored password hash
            final loginResult = await login(
              phone: user.phone,
              passwordHash: user.passwordHash!,
              passwordSalt: user.passwordSalt!,
            );

            return loginResult.fold(
              (loginFailure) => Left(loginFailure),
              (newUser) async {
                final userWithPasswordHash = User(
                  memberId: newUser.memberId,
                  phone: newUser.phone,
                  token: newUser.token,
                  passwordHash: user.passwordHash,
                  passwordSalt: user.passwordSalt,
                  passwordChanged: user.passwordChanged,
                  dashboard: newUser.dashboard,
                );

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
      return Left(InfrastructureFailure(e.toString()));
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
      return Left(InfrastructureFailure(e.toString()));
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
      final ({String hash, String salt}) hashResult =
          await _passwordService.hashPassword(password);

      final url = '$baseUrl/onboardMember';
      final body = {
        'firstname': firstName,
        'lastname': lastName,
        'phone': phone,
        'defaultDenom': 'CXX',
        'password_hash': hashResult.hash,
        'password_salt': hashResult.salt,
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

  @override
  Future<Either<Failure, User>> login({
    required String phone,
    String? password,
    String? passwordHash,
    String? passwordSalt,
  }) async {
    try {
      final url = '$baseUrl/login';
      final body = {
        'phone': phone,
      };

      if (passwordHash != null && passwordSalt != null) {
        // Use existing hash for token refresh
        body['password_hash'] = passwordHash;
        body['password_salt'] = passwordSalt;
      } else {
        if (password == null) {
          return const Left(InfrastructureFailure('Password is required'));
        }
        // Hash new password
        final ({String hash, String salt}) hashResult =
            await _passwordService.hashPassword(password);
        body['password_hash'] = hashResult.hash;
        body['password_salt'] = hashResult.salt;
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

        final dashboardObj = dashboard.Dashboard.fromMap({
          'member': {
            'memberID': actionDetails['memberID'],
            'memberTier': dashboardData['member']['memberTier'],
            'firstname': dashboardData['member']['firstname'],
            'lastname': dashboardData['member']['lastname'],
            'memberHandle':
                dashboardData['member']['memberHandle'] as String? ?? '',
            'defaultDenom': dashboardData['member']['defaultDenom'],
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
        });

        final user = User(
          memberId: memberId,
          phone: userPhone,
          token: token,
          passwordHash: body['password_hash'],
          passwordSalt: body['password_salt'],
          passwordChanged: DateTime.now(),
          dashboard: dashboardObj,
        );

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
        final url = 'https://dev.mycredex.dev/acceptCredex';
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
            final dashboardObj = dashboard.Dashboard.fromMap({
              'member': {
                'memberID': dashboardData['member']['memberID'],
                'memberTier': dashboardData['member']['memberTier'],
                'firstname': dashboardData['member']['firstname'],
                'lastname': dashboardData['member']['lastname'],
                'memberHandle': dashboardData['member']['memberHandle'] as String? ?? '',
                'defaultDenom': dashboardData['member']['defaultDenom'],
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
            });

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
