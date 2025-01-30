import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';

class AcceptCredex {
  final AccountRepository repository;

  AcceptCredex(this.repository);

  Future<Either<Failure, bool>> call(String credexId) async {
    return await repository.acceptCredex(credexId);
  }
}
