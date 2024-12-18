import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/domain/entities/account.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart' as credex;
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/infrastructure/services/network_logger.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';

class AccountRepositoryImpl implements AccountRepository {
  final String baseUrl = ApiConfig.baseUrl;
  
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final SecurityService _securityService = SecurityService();

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
          if (!isRetry && failure.message?.toLowerCase().contains('token expired') == true) {
            // Use stored password for re-authentication
            if (user.password == null) {
              return const Left(InfrastructureFailure('Authentication failed: No stored password'));
            }

            final loginResult = await login(
              phone: user.phone,
              password: user.password!, // Force non-null since we checked above
            );

            return loginResult.fold(
              (loginFailure) => Left(loginFailure),
              (newUser) async {
                // Preserve the password when saving the new user data
                final userWithPassword = User(
                  memberId: newUser.memberId,
                  phone: newUser.phone,
                  token: newUser.token,
                  password: user.password, // Keep the existing password
                  dashboard: newUser.dashboard,
                );
                
                final saveResult = await saveUser(userWithPassword);
                
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
  Future<Either<Failure, Map<String, dynamic>>> getLedger({
    required String accountId,
    int? startRow,
    int? numRows,
  }) async {
    return _executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/getLedger'; // Changed back to '/getLedger'
        final headers = _authHeaders(token);
        final body = {
          'accountID': accountId,
          if (startRow != null) 'startRow': startRow,
          if (numRows != null) 'numRows': numRows,
        };

        Logger.data('Fetching ledger for account $accountId');
        Logger.data('Request URL: $url');
        Logger.data('Request body: $body');

        try {
          final response = await _loggedRequest(
            () => http.post(
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
            final data = json.decode(response.body);
            Logger.data('Successfully fetched ledger for account $accountId');
            return Right(data as Map<String, dynamic>);
          } else {
            final errorBody = json.decode(response.body);
            final errorMessage = errorBody['message'] ?? 'Failed to get ledger';
            Logger.error('Failed to fetch ledger for account $accountId: $errorMessage');
            Logger.error('Response status: ${response.statusCode}');
            Logger.error('Response body: ${response.body}');
            return Left(InfrastructureFailure(errorMessage));
          }
        } catch (e, stackTrace) {
          Logger.error('Exception fetching ledger for account $accountId', e, stackTrace);
          return Left(InfrastructureFailure('Network error: ${e.toString()}'));
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
          () => http.get(Uri.parse(url), headers: headers),
          url,
          'GET',
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return Right(Map<String, double>.from(data['balances']));
        } else {
          final errorMessage = json.decode(response.body)['message'] ?? 'Failed to get balances';
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
          () => http.post(
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
            balances: {}, // Balances not included in this response
          ));
        } else {
          final errorMessage = json.decode(response.body)['message'] ?? 'Failed to get account';
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
      final url = '$baseUrl/onboardMember';
      final body = {
        'firstname': firstName,
        'lastname': lastName,
        'phone': phone,
        'defaultDenom': 'CXX',
        'password': password
      };

      final response = await _loggedRequest(
        () => http.post(
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
        final errorMessage = json.decode(response.body)['message'] ?? 'Failed to onboard member';
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final url = '$baseUrl/login';
      final body = {
        'phone': phone,
        'password': password,
      };

      final response = await _loggedRequest(
        () => http.post(
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
        
        // Add null checks for required User fields
        final memberId = actionDetails['memberID']?.toString();
        final userPhone = actionDetails['phone']?.toString();
        final token = actionDetails['token']?.toString();
        
        if (memberId == null || userPhone == null || token == null) {
          return const Left(InfrastructureFailure('Missing required user fields in response'));
        }

        final dashboardData = jsonResponse['data']['dashboard'];
        
        // Create a Set to track unique account handles
        final seenHandles = <String>{};
        
        final accountsList = (dashboardData['accounts'] as List)
            .where((account) => account['success'] == true)
            .map((account) {
              final accountData = account['data'];
              final balanceData = accountData['balanceData']['data'];
              final pendingInData = accountData['pendingInData'];
              final pendingOutData = accountData['pendingOutData'];
              final sendOffersToData = accountData['sendOffersTo'];
              
              return dashboard.DashboardAccount(
                accountID: accountData['accountID'],
                accountName: accountData['accountName'],
                accountHandle: accountData['accountHandle'],
                defaultDenom: accountData['defaultDenom'],
                isOwnedAccount: accountData['isOwnedAccount'],
                authFor: (accountData['authFor'] as List)
                    .map((auth) => dashboard.AuthUser(
                          firstname: auth['firstname'],
                          lastname: auth['lastname'],
                          memberID: auth['memberID'],
                        ))
                    .toList(),
                balanceData: dashboard.BalanceData(
                  securedNetBalancesByDenom: 
                      (balanceData['securedNetBalancesByDenom'] as List)
                          .map((balance) => balance.toString())
                          .toList(),
                  unsecuredBalances: dashboard.UnsecuredBalances(
                    totalPayables: balanceData['unsecuredBalancesInDefaultDenom']['totalPayables'],
                    totalReceivables: balanceData['unsecuredBalancesInDefaultDenom']['totalReceivables'],
                    netPayRec: balanceData['unsecuredBalancesInDefaultDenom']['netPayRec'],
                  ),
                  netCredexAssetsInDefaultDenom: balanceData['netCredexAssetsInDefaultDenom'],
                ),
                pendingInData: credex.PendingData(
                  success: pendingInData['success'],
                  data: (pendingInData['data'] as List).map((offer) => credex.PendingOffer(
                    credexID: offer['credexID'],
                    formattedInitialAmount: offer['formattedInitialAmount'],
                    counterpartyAccountName: offer['counterpartyAccountName'],
                    secured: offer['secured'],
                  )).toList(),
                  message: pendingInData['message'],
                ),
                pendingOutData: credex.PendingData(
                  success: pendingOutData['success'],
                  data: (pendingOutData['data'] as List).map((offer) => credex.PendingOffer(
                    credexID: offer['credexID'],
                    formattedInitialAmount: offer['formattedInitialAmount'],
                    counterpartyAccountName: offer['counterpartyAccountName'],
                    secured: offer['secured'],
                  )).toList(),
                  message: pendingOutData['message'],
                ),
                sendOffersTo: dashboard.AuthUser(
                  firstname: sendOffersToData['firstname'],
                  lastname: sendOffersToData['lastname'],
                  memberID: sendOffersToData['memberID'],
                ),
              );
            })
            .where((account) => seenHandles.add(account.accountHandle))
            .toList();

        final dashboardObj = dashboard.Dashboard(
          id: actionDetails['memberID'],
          memberTier: dashboard.MemberTier(
            low: dashboardData['memberTier']['low'],
            high: dashboardData['memberTier']['high'],
          ),
          remainingAvailableUSD: dashboard.RemainingAvailable(
            low: dashboardData['remainingAvailableUSD']['low'],
            high: dashboardData['remainingAvailableUSD']['high'],
          ),
          accounts: accountsList,
          firstname: actionDetails['firstname'],
          lastname: actionDetails['lastname'],
          defaultDenom: actionDetails['defaultDenom']?.toString(),
        );
        
        final user = User(
          memberId: memberId,
          phone: userPhone,
          token: token,
          password: password, // Include password in user object
          dashboard: dashboardObj,
        );
        
        return Right(user);
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Login failed';
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, credex.CredexResponse>> createCredex(CredexRequest request) async {
    return _executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/createCredex';
        final headers = _authHeaders(token);
        final body = request.toJson();

        final response = await _loggedRequest(
          () => http.post(
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
          final data = jsonResponse['data'];
          final action = data['action'];
          final dashboard = data['dashboard'];
          final dashboardData = dashboard['data'];
          final balanceData = dashboardData['balanceData'];

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
                  receiverAccountName: action['details']['receiverAccountName'],
                ),
              ),
              dashboard: credex.CredexDashboard(
                success: dashboard['success'],
                data: credex.CredexDashboardData(
                  accountID: dashboardData['accountID'],
                  accountName: dashboardData['accountName'],
                  accountHandle: dashboardData['accountHandle'],
                  defaultDenom: dashboardData['defaultDenom'],
                  isOwnedAccount: dashboardData['isOwnedAccount'],
                  authFor: (dashboardData['authFor'] as List).map((auth) => credex.AuthUser(
                    lastname: auth['lastname'],
                    firstname: auth['firstname'],
                    memberID: auth['memberID'],
                  )).toList(),
                  balanceData: credex.BalanceData(
                    success: balanceData['success'],
                    data: credex.BalanceDataDetails(
                      securedNetBalancesByDenom: 
                          (balanceData['data']['securedNetBalancesByDenom'] as List)
                              .map((balance) => balance.toString())
                              .toList(),
                      unsecuredBalancesInDefaultDenom: credex.UnsecuredBalances(
                        totalPayables: balanceData['data']['unsecuredBalancesInDefaultDenom']['totalPayables'],
                        totalReceivables: balanceData['data']['unsecuredBalancesInDefaultDenom']['totalReceivables'],
                        netPayRec: balanceData['data']['unsecuredBalancesInDefaultDenom']['netPayRec'],
                      ),
                      netCredexAssetsInDefaultDenom: balanceData['data']['netCredexAssetsInDefaultDenom'],
                    ),
                    message: balanceData['message'],
                  ),
                  pendingInData: credex.PendingData(
                    success: dashboardData['pendingInData']['success'],
                    data: (dashboardData['pendingInData']['data'] as List).map((offer) => credex.PendingOffer(
                      credexID: offer['credexID'],
                      formattedInitialAmount: offer['formattedInitialAmount'],
                      counterpartyAccountName: offer['counterpartyAccountName'],
                      secured: offer['secured'],
                    )).toList(),
                    message: dashboardData['pendingInData']['message'],
                  ),
                  pendingOutData: credex.PendingData(
                    success: dashboardData['pendingOutData']['success'],
                    data: (dashboardData['pendingOutData']['data'] as List).map((offer) => credex.PendingOffer(
                      credexID: offer['credexID'],
                      formattedInitialAmount: offer['formattedInitialAmount'],
                      counterpartyAccountName: offer['counterpartyAccountName'],
                      secured: offer['secured'],
                    )).toList(),
                    message: dashboardData['pendingOutData']['message'],
                  ),
                  sendOffersTo: credex.SendOffersTo(
                    memberID: dashboardData['sendOffersTo']['memberID'],
                    firstname: dashboardData['sendOffersTo']['firstname'],
                    lastname: dashboardData['sendOffersTo']['lastname'],
                  ),
                ),
                message: dashboard['message'],
              ),
            ),
          ));
        } else {
          final errorMessage = json.decode(response.body)['message'] ?? 'Failed to create Credex';
          return Left(InfrastructureFailure(errorMessage));
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
          () => http.post(
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
          final errorMessage = json.decode(response.body)['message'] ?? 'Failed to accept Credex transactions';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }
}
