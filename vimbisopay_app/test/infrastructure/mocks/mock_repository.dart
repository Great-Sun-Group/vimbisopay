import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/account.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart' as credex;
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'api_responses.dart';
import 'mock_account.dart';

class MockAccountRepository implements AccountRepository {
  bool shouldSucceed;
  
  MockAccountRepository({this.shouldSucceed = true});

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
  Future<Either<Failure, Map<String, dynamic>>> getLedger({
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
  Future<Either<Failure, bool>> acceptCredexBulk(List<String> credexIds) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldSucceed) {
      return const Right(true);
    } else {
      return const Left(InfrastructureFailure('Failed to accept credex'));
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
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
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
}
