import 'package:dartz/dartz.dart';
import '../entities/account.dart';
import '../entities/user.dart';
import '../../core/error/failures.dart';

abstract class AccountRepository {
  Future<Either<Failure, User>> login({
    required String phone,
    required String password,
  });

  Future<Either<Failure, bool>> onboardMember({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
  });

  Future<Either<Failure, User?>> getCurrentUser();
  
  Future<Either<Failure, Map<String, double>>> getBalances();
  
  Future<Either<Failure, List>> getLedger({int? startRow, int? numRows});

  Future<Either<Failure, Account>> getAccountByHandle(String handle);
}
