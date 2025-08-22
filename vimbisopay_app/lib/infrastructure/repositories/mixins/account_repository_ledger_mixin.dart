import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/core/error/exceptions.dart';
import 'package:vimbisopay_app/domain/entities/account.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/counterparty_credit_report.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/repositories/base_account_repository.dart';

/// Mixin that provides ledger and account-related methods for AccountRepositoryImpl
mixin AccountRepositoryLedgerMixin on BaseAccountRepository {
  
  @override
  Future<Either<Failure, List<LedgerEntry>>> getLedger({
    required String accountId,
    DateTime? afterTimestamp,
    int? limit,
  }) async {
    try {
      // Check if we have any cached entries
      final hasCachedEntries = await databaseHelper.hasLedgerEntries(accountId);
      final cachedEntries = await databaseHelper.getLedgerEntries(accountId);
      
      // If no afterTimestamp provided and we have cached entries, return from cache
      if (afterTimestamp == null && hasCachedEntries) {
        Logger.data('Returning ${cachedEntries.length} cached ledger entries');
        return Right(cachedEntries);
      }

      // Get latest timestamp from cache if not provided and we have cached entries
      final latestTimestamp = afterTimestamp ?? (hasCachedEntries ? await databaseHelper.getLatestLedgerTimestamp(accountId) : null);
      
      // Fetch from API
      return executeAuthenticatedRequest(
        request: (token) async {
          final url = '$baseUrl/getLedger';
          final headers = authHeaders(token);
          final body = {
            'accountID': accountId,
            if (latestTimestamp != null) 'afterTimestamp': latestTimestamp.toIso8601String(),
            if (limit != null || !hasCachedEntries) 'numRows': limit ?? 1000, // Load all entries if cache is empty
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
              await databaseHelper.saveLedgerEntries(newEntries, accountId);
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
    return executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/getLedger';
        final headers = authHeaders(token);
        final body = {
          'accountID': accountId,
          if (startRow != null) 'startRow': startRow,
          if (numRows != null) 'numRows': numRows,
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
  Future<Either<Failure, Map<String, double>>> getBalances() async {
    return executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/balances';
        final headers = authHeaders(token);

        final response = await loggedRequest(
          () => httpClient.get(Uri.parse(url), headers: headers),
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
    return executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/getAccountByHandle';
        final headers = authHeaders(token);
        final body = {'accountHandle': handle};

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
  Future<Either<Failure, CounterpartyCreditReport>> getCounterpartyCreditReport({
    required String memberId,
  }) async {
    return executeAuthenticatedRequest(
      request: (token) async {
        final url = '$baseUrl/getCounterpartyCreditReport';
        final headers = authHeaders(token);
        final body = {'memberID': memberId};

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
          final jsonResponse = json.decode(response.body);

          if (!jsonResponse.containsKey('data') ||
              !jsonResponse['data'].containsKey('creditReport')) {
            return const Left(InfrastructureFailure('Invalid response format'));
          }

          final creditReportData = jsonResponse['data']['creditReport'];
          
          try {
            // Parse credit rating if available
            CreditRating? creditRating;
            if (creditReportData.containsKey('creditRating') && creditReportData['creditRating'] != null) {
              final creditRatingMap = creditReportData['creditRating'] as Map<String, dynamic>;
              creditRating = CreditRating(
                redeemedTotalUSD: (creditRatingMap['redeemedTotal'] as num?)?.toDouble() ?? 0.0,
                outstandingTotalUSD: (creditRatingMap['outstandingTotal'] as num?)?.toDouble() ?? 0.0,
                defaultedTotalUSD: (creditRatingMap['defaultedTotal'] as num?)?.toDouble() ?? 0.0,
                writtenOffTotalUSD: (creditRatingMap['writtenOffTotal'] as num?)?.toDouble() ?? 0.0,
              );
            }

            // Parse accounts if available with comprehensive error handling
            List<CounterpartyAccount> accounts = [];
            if (creditReportData.containsKey('accounts') && creditReportData['accounts'] != null) {
              final accountsList = creditReportData['accounts'] as List;
              for (final accountData in accountsList) {
                try {
                  if (accountData is Map<String, dynamic>) {
                    // Create a safe map with null-safe string extraction
                    final safeAccountMap = <String, dynamic>{
                      'accountID': _safeStringExtract(accountData, 'accountID') ?? '',
                      'accountName': _safeStringExtract(accountData, 'accountName') ?? '',
                      'accountHandle': _safeStringExtract(accountData, 'accountHandle') ?? '',
                      'accountType': _safeStringExtract(accountData, 'accountType') ?? 'STANDARD',
                      'defaultDenom': _safeStringExtract(accountData, 'defaultDenom') ?? 'USD',
                      'isOwnedAccount': accountData['isOwnedAccount'] as bool? ?? true,
                    };
                    accounts.add(CounterpartyAccount.fromMap(safeAccountMap));
                  }
                } catch (e) {
                  Logger.error('Error parsing individual account', e);
                  // Continue processing other accounts
                }
              }
            }

            // Safe parsing of member name with null checks
            final memberName = _safeStringExtract(creditReportData, 'memberName') ?? '';
            final nameParts = memberName.isNotEmpty ? memberName.split(' ') : [''];
            final firstname = nameParts.isNotEmpty ? nameParts.first : '';
            final lastname = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

            // Safe parsing of member handle (backend returns empty string, not null)
            final memberHandleRaw = _safeStringExtract(creditReportData, 'memberHandle');
            final memberHandle = (memberHandleRaw != null && memberHandleRaw.isNotEmpty) ? memberHandleRaw : null;

            // Safe parsing of profile picture thumbnail
            String? profilePictureThumbnail;
            if (creditReportData.containsKey('profilePictureUrls') && 
                creditReportData['profilePictureUrls'] != null) {
              final profileUrls = creditReportData['profilePictureUrls'] as Map<String, dynamic>;
              profilePictureThumbnail = _safeStringExtract(profileUrls, 'thumbnail');
            }

            // Safe parsing of required fields
            final memberID = _safeStringExtract(creditReportData, 'memberID');
            final reportGeneratedAtStr = _safeStringExtract(creditReportData, 'reportGeneratedAt');

            if (memberID == null || memberID.isEmpty) {
              return const Left(InfrastructureFailure('Missing memberID in response'));
            }

            DateTime reportGeneratedAt;
            try {
              reportGeneratedAt = reportGeneratedAtStr != null 
                  ? DateTime.parse(reportGeneratedAtStr)
                  : DateTime.now();
            } catch (e) {
              Logger.error('Error parsing reportGeneratedAt, using current time', e);
              reportGeneratedAt = DateTime.now();
            }

            final report = CounterpartyCreditReport(
              id: memberID,
              memberID: memberID,
              firstname: firstname,
              lastname: lastname,
              memberHandle: memberHandle,
              memberTier: 1, // Default tier since not provided by backend
              profilePictureThumbnail: profilePictureThumbnail,
              creditRating: creditRating,
              accounts: accounts,
              reportGeneratedAt: reportGeneratedAt,
            );

            return Right(report);
          } catch (e) {
            Logger.error('Error parsing credit report data', e);
            return Left(InfrastructureFailure('Error parsing credit report: ${e.toString()}'));
          }
        } else if (response.statusCode == 404) {
          return const Left(InfrastructureFailure('Member not found'));
        } else {
          final errorMessage = json.decode(response.body)['message'] ?? 'Failed to get credit report';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }

  /// Safely extract a string value from a map, handling null and type casting issues
  String? _safeStringExtract(Map<String, dynamic> map, String key) {
    try {
      final value = map[key];
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    } catch (e) {
      Logger.error('Error extracting string for key: $key', e);
      return null;
    }
  }
}
