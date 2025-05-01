import 'dart:convert';
import 'dart:io' show Platform;
import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart' as credex;
import 'package:vimbisopay_app/domain/entities/recurring_request.dart';
import 'package:vimbisopay_app/domain/entities/recurring_response.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/infrastructure/repositories/base_account_repository.dart';

/// Mixin that provides Credex and recurring payment-related methods for AccountRepositoryImpl
mixin AccountRepositoryCredexMixin on BaseAccountRepository {
  
  @override
  Future<Either<Failure, credex.CredexResponse>> createCredex(
      CredexRequest request) async {
    Logger.data('Creating Credex request: ${request.toJson()}');

    return executeAuthenticatedRequest(
      request: (token) async {
        try {
          final url = '$baseUrl/createCredex';
          final headers = authHeaders(token);
          final body = request.toJson();

          Logger.data('Sending Credex request to $url');
          final response = await loggedRequest(
            () => httpClient.post(
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
    return executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/acceptCredexBulk';
        final headers = authHeaders(token);
        final body = {'credexIDs': credexIds};

        final response = await loggedRequest(
          () => httpClient.post(
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
    return executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/acceptCredex';
        final headers = authHeaders(token);
        final body = {'credexID': credexId};

        final response = await loggedRequest(
          () => httpClient.post(
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
    return executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/cancelCredex';
        final headers = authHeaders(token);
        final body = {'credexID': credexId};

        final response = await loggedRequest(
          () => httpClient.post(
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
    return executeAuthenticatedRequest(
      request: (authToken) async {
        final url = '$baseUrl/api/notifications/register-token';
        final headers = authHeaders(authToken);
        final body = {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android'
        };

        final response = await loggedRequest(
          () => httpClient.post(
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

    return executeAuthenticatedRequest(
      request: (token) async {
        try {
          final url = '$baseUrl/createRecurring';
          final headers = authHeaders(token);
          final body = request.toJson();

          Logger.data('Sending Recurring request to $url');
          final response = await loggedRequest(
            () => httpClient.post(
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
                              calculateUnsecuredBalances(
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

  @override
  Future<Either<Failure, bool>> upgradeToHustler10k(String accountId) async {
    Logger.data('[UPGRADE_TO_HUSTLER10K] Starting upgrade for account: $accountId');
    
    return executeAuthenticatedRequest(
      request: (token) async {
        try {
          final url = '$baseUrl/hustler10k';
          final headers = authHeaders(token);
          final body = {'personalAccountID': accountId};

          Logger.data('[UPGRADE_TO_HUSTLER10K] Sending request to $url');
          final response = await loggedRequest(
            () => httpClient.post(
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
}
