import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/domain/entities/account.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/infrastructure/services/network_logger.dart';

class AccountRepositoryImpl implements AccountRepository {
  final String baseUrl = 'https://dev.mycredex.dev';
  
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
        return Left(InfrastructureFailure('Not authenticated'));
      }

      final result = await request(user.token);

      return result.fold(
        (failure) async {
          if (!isRetry && failure.message?.toLowerCase().contains('token expired') == true) {
            final loginResult = await login(
              phone: user.phone,
              password: 'password', // TODO using dummy password as specified
            );

            return loginResult.fold(
              (loginFailure) => Left(loginFailure),
              (newUser) async {
                final saveResult = await saveUser(newUser);
                
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
  Future<Either<Failure, Map<String, dynamic>>> getLedger({
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
          return Right(data as Map<String, dynamic>);
        } else {
          final errorMessage = json.decode(response.body)['message'] ?? 'Failed to get ledger';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }

  @override
  Future<Either<Failure, Account>> getAccountByHandle(String handle) async {
    return _executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/accounts/$handle';
        final headers = _authHeaders(token);

        final response = await _loggedRequest(
          () => http.get(Uri.parse(url), headers: headers),
          url,
          'GET',
          headers: headers,
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return Right(Account(
            id: data['id'],
            handle: data['handle'],
            name: data['name'],
            defaultDenom: data['defaultDenom'],
            balances: Map<String, double>.from(data['balances']),
          ));
        } else {
          final errorMessage = json.decode(response.body)['message'] ?? 'Failed to get account';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }

  @override
  Future<Either<Failure, Dashboard>> getMemberDashboardByPhone(String phone) async {
    return _executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/getMemberDashboardByPhone';
        final headers = _authHeaders(token);
        final body = {'phone': phone};

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
          
          if (!data.containsKey('data') || 
              !data['data'].containsKey('action') ||
              !data['data'].containsKey('dashboard')) {
            return Left(InfrastructureFailure('Invalid response format'));
          }

          final actionDetails = data['data']['action']['details'];
          final dashboardData = data['data']['dashboard'];
          
          final accountsList = (dashboardData['accounts'] as List)
              .where((account) => account['success'] == true)
              .map((account) {
                final accountData = account['data'];
                final balanceData = accountData['balanceData']['data'];
                
                return DashboardAccount(
                  accountID: accountData['accountID'],
                  accountName: accountData['accountName'],
                  accountHandle: accountData['accountHandle'],
                  defaultDenom: accountData['defaultDenom'],
                  isOwnedAccount: accountData['isOwnedAccount'],
                  authFor: (accountData['authFor'] as List)
                      .map((auth) => AuthUser(
                            firstname: auth['firstname'],
                            lastname: auth['lastname'],
                            memberID: auth['memberID'],
                          ))
                      .toList(),
                  balanceData: BalanceData(
                    securedNetBalancesByDenom: 
                        (balanceData['securedNetBalancesByDenom'] as List)
                            .map((balance) => balance.toString())
                            .toList(),
                    unsecuredBalances: UnsecuredBalances(
                      totalPayables: balanceData['unsecuredBalancesInDefaultDenom']['totalPayables'],
                      totalReceivables: balanceData['unsecuredBalancesInDefaultDenom']['totalReceivables'],
                      netPayRec: balanceData['unsecuredBalancesInDefaultDenom']['netPayRec'],
                    ),
                    netCredexAssetsInDefaultDenom: balanceData['netCredexAssetsInDefaultDenom'],
                  ),
                );
              })
              .toList();

          return Right(Dashboard(
            id: actionDetails['memberID'],
            memberHandle: actionDetails['memberHandle'],
            firstname: actionDetails['firstname'],
            lastname: actionDetails['lastname'],
            defaultDenom: actionDetails['defaultDenom'],
            memberTier: MemberTier(
              low: actionDetails['memberTier']['low'],
              high: actionDetails['memberTier']['high'],
            ),
            remainingAvailableUSD: actionDetails['remainingAvailableUSD'],
            accounts: accountsList,
          ));
        } else {
          final errorMessage = json.decode(response.body)['message'] ?? 'Failed to get dashboard';
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
            !jsonResponse['data']['action'].containsKey('details')) {
          return Left(InfrastructureFailure('Invalid response format'));
        }

        final actionDetails = jsonResponse['data']['action']['details'];
        
        final user = User(
          memberId: actionDetails['memberID'],
          phone: actionDetails['phone'],
          token: actionDetails['token'],
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
}
