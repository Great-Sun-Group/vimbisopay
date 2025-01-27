import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/domain/entities/account.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart';

abstract class AccountRepository {
  Future<Either<Failure, User>> login({
    required String phone,
    String? password,
    String? passwordHash,
    String? passwordSalt,
  });

  Future<Either<Failure, bool>> onboardMember({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
  });

  Future<Either<Failure, User?>> getCurrentUser();
  
  Future<Either<Failure, bool>> saveUser(User user);
  
  Future<Either<Failure, Map<String, double>>> getBalances();
  
  Future<Either<Failure, Map<String, dynamic>>> getLedger({
    required String accountId,
    int? startRow,
    int? numRows,
  });

  Future<Either<Failure, Account>> getAccountByHandle(String handle);

  Future<Either<Failure, CredexResponse>> createCredex(CredexRequest request);

  Future<Either<Failure, bool>> acceptCredexBulk(List<String> credexIds);

  Future<Either<Failure, bool>> cancelCredex(String credexId);

  Future<Either<Failure, bool>> registerNotificationToken(String token);
}
