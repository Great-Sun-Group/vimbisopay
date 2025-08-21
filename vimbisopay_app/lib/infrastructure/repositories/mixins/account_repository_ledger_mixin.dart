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
          
          // Parse credit rating if available
          CreditRating? creditRating;
          if (creditReportData.containsKey('creditRating') && creditReportData['creditRating'] != null) {
            final creditRatingMap = creditReportData['creditRating'] as Map<String, dynamic>;
            creditRating = CreditRating(
              redeemedTotalUSD: (creditRatingMap['redeemedTotal'] as num).toDouble(),
              outstandingTotalUSD: (creditRatingMap['outstandingTotal'] as num).toDouble(),
              defaultedTotalUSD: (creditRatingMap['defaultedTotal'] as num).toDouble(),
              writtenOffTotalUSD: (creditRatingMap['writtenOffTotal'] as num).toDouble(),
            );
          }

          // Parse accounts if available
          List<CounterpartyAccount> accounts = [];
          if (creditReportData.containsKey('accounts') && creditReportData['accounts'] != null) {
            accounts = (creditReportData['accounts'] as List)
                .map((account) => CounterpartyAccount.fromMap(account as Map<String, dynamic>))
                .toList();
          }

          // Parse member name
          final memberName = creditReportData['memberName'] as String;
          final nameParts = memberName.split(' ');
          final firstname = nameParts.isNotEmpty ? nameParts.first : '';
          final lastname = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

          final report = CounterpartyCreditReport(
            id: creditReportData['memberID'] as String,
            memberID: creditReportData['memberID'] as String,
            firstname: firstname,
            lastname: lastname,
            memberHandle: creditReportData['memberHandle'] as String?,
            memberTier: 1, // Default tier since not provided by backend
            profilePictureThumbnail: creditReportData['profilePictureUrls'] != null && 
                creditReportData['profilePictureUrls']['thumbnail'] != null
                ? creditReportData['profilePictureUrls']['thumbnail'] as String
                : null,
            creditRating: creditRating,
            accounts: accounts,
            reportGeneratedAt: DateTime.parse(creditReportData['reportGeneratedAt'] as String),
          );

          return Right(report);
        } else if (response.statusCode == 404) {
          return const Left(InfrastructureFailure('Member not found'));
        } else {
          final errorMessage = json.decode(response.body)['message'] ?? 'Failed to get credit report';
          return Left(InfrastructureFailure(errorMessage));
        }
      },
    );
  }
}
