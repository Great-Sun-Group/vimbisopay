import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/account.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/domain/entities/recurring_request.dart';
import 'package:vimbisopay_app/domain/entities/recurring_response.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart' as credex;
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dash;
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'api_responses.dart';
import 'mock_account.dart';

class MockAccountRepository implements AccountRepository {
  bool shouldSucceed;
  
  MockAccountRepository({this.shouldSucceed = true});

  @override
  Future<Either<Failure, User>> loginV2({
    required String phone,
    String? password,
    String? passwordHash,
    String? passwordSalt,
  }) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      const data = MockApiResponses.loginSuccess;
      if (data['data'] == null) {
        return const Left(InfrastructureFailure('Invalid data format'));
      }
      return Right(User.fromMap(data['data'] as Map<String, dynamic>));
    } else {
      return const Left(InfrastructureFailure('Invalid credentials'));
    }
  }

  @override
  Future<Either<Failure, User>> login({
    required String phone,
    String? password,
    String? passwordHash,
    String? passwordSalt,
  }) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      const data = MockApiResponses.loginSuccess;
      if (data['data'] == null) {
        return const Left(InfrastructureFailure('Invalid data format'));
      }
      return Right(User.fromMap(data['data'] as Map<String, dynamic>));
    } else {
      return const Left(InfrastructureFailure('Invalid credentials'));
    }
  }

  @override
  Future<Either<Failure, List<LedgerEntry>>> getLedger({
    required String accountId,
    DateTime? afterTimestamp,
    int? limit,
  }) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      // Return empty list for now - we'll add mock entries later if needed
      return const Right([]);
    } else {
      return const Left(InfrastructureFailure('Failed to get ledger'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getLedgerLegacy({
    required String accountId,
    int? startRow,
    int? numRows,
  }) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return const Right(MockApiResponses.emptyLedger);
    } else {
      return const Left(InfrastructureFailure('Failed to get ledger'));
    }
  }

  @override
  Future<Either<Failure, credex.CredexResponse>> createCredex(CredexRequest request) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return Right(credex.CredexResponse(
        message: 'Success',
        data: credex.CredexData(
          action: credex.CredexAction(
            id: '123',
            type: 'CREATE',
            timestamp: DateTime.now().toIso8601String(),
            actor: 'TEST',
            details: credex.CredexActionDetails(
              amount: '100',
              denomination: 'CXX',
              securedCredex: false,
              receiverAccountID: '456',
              receiverAccountName: 'Test Account',
            ),
          ),
          dashboard: credex.CredexDashboard(
            member: credex.DashboardMember(
              memberID: '123',
              memberTier: 0,
              firstname: 'John',
              lastname: 'Doe',
              defaultDenom: 'CXX',
            ),
            accounts: [],
          ),
        ),
      ));
    } else {
      return const Left(InfrastructureFailure('Failed to create credex'));
    }
  }

  @override
  Future<Either<Failure, bool>> acceptCredex(String credexId) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return const Right(true);
    } else {
      return const Left(InfrastructureFailure('Failed to accept credex'));
    }
  }

  @override
  Future<Either<Failure, bool>> acceptCredexBulk(List<String> credexIds) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return const Right(true);
    } else {
      return const Left(InfrastructureFailure('Failed to accept credex bulk'));
    }
  }

  @override
  Future<Either<Failure, bool>> cancelCredex(String credexId) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return const Right(true);
    } else {
      return const Left(InfrastructureFailure('Failed to cancel credex'));
    }
  }

  @override
  Future<Either<Failure, bool>> registerNotificationToken(String token) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return const Right(true);
    } else {
      return const Left(InfrastructureFailure('Failed to register token'));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      const data = MockApiResponses.loginSuccess;
      if (data['data'] == null) {
        return const Right(null);
      }
      return Right(User.fromMap(data['data'] as Map<String, dynamic>));
    } else {
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, Map<String, double>>> getBalances() async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return const Right({'CXX': 100.0});
    } else {
      return const Left(InfrastructureFailure('Failed to get balances'));
    }
  }

  @override
  Future<Either<Failure, bool>> onboardMember({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return const Right(true);
    } else {
      return const Left(InfrastructureFailure('Failed to onboard member'));
    }
  }

  @override
  Future<Either<Failure, Account>> getAccountByHandle(String handle) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return Right(MockAccount.standard());
    } else {
      return const Left(InfrastructureFailure('Failed to get account'));
    }
  }

  @override
  Future<Either<Failure, bool>> saveUser(User user) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return const Right(true);
    } else {
      return const Left(InfrastructureFailure('Failed to save user'));
    }
  }

  @override
  Future<Either<Failure, bool>> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return const Right(true);
    } else {
      return const Left(InfrastructureFailure('Failed to request OTP'));
    }
  }

  @override
  Future<Either<Failure, bool>> verifyOtp({
    required String token,
    required String otp,
    required String memberId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return const Right(true);
    } else {
      return const Left(InfrastructureFailure('Failed to verify OTP'));
    }
  }

  @override
  Future<Either<Failure, User>> setInitialPassword({
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return Right(User(
        memberId: 'test-member-id',
        phone: '+353834140206',
        token: 'test-token',
        passwordHash: 'test-hash',
        passwordSalt: 'test-salt',
        passwordChanged: DateTime.now(),
      ));
    } else {
      return const Left(InfrastructureFailure('Failed to set initial password'));
    }
  }

  @override
  Future<Either<Failure, RecurringResponse>> createRecurring(RecurringRequest request) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      final now = DateTime.now();
      final mockDashboard = dash.Dashboard.fromMap({
        'member': {
          'memberID': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
          'memberTier': 1,
          'firstname': 'John',
          'lastname': 'Doe',
          'memberHandle': '123456789',
          'defaultDenom': 'USD',
        },
        'accounts': [
          {
            'accountID': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
            'accountName': 'John Doe Personal',
            'accountHandle': '123456789',
            'defaultDenom': 'USD',
            'isOwnedAccount': true,
            'balanceData': {
              'securedNetBalancesByDenom': ['10.00 USD'],
              'unsecuredBalancesInDefaultDenom': {
                'totalPayables': '0.00 USD',
                'totalReceivables': '0.00 USD',
                'netPayRec': '0.00 USD',
              },
              'netCredexAssetsInDefaultDenom': '10.00 USD',
            },
            'pendingInData': [],
            'pendingOutData': [],
            'sendOffersTo': {
              'memberID': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
              'firstname': 'John',
              'lastname': 'Doe',
            },
          },
        ],
      });

      return Right(RecurringResponse(
        message: 'Recurring transaction created successfully',
        data: RecurringData(
          action: RecurringAction(
            id: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
            type: 'RECURRING_CREATED',
            timestamp: now.toIso8601String(),
            actor: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
            details: RecurringActionDetails(
              recurringID: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
              amount: request.amount.toString(),
              denomination: request.denomination,
              payFrequency: request.payFrequency,
              nextDate: NextDate(
                year: YearValue(low: now.year, high: 0),
                month: YearValue(low: now.month, high: 0),
                day: YearValue(low: now.day, high: 0),
              ),
              status: 'PENDING',
            ),
          ),
          dashboard: mockDashboard,
        ),
      ));
    } else {
      return const Left(InfrastructureFailure('Failed to create recurring transaction'));
    }
  }
}
