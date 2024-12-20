import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';

class CancelCredex {
  final AccountRepository repository;

  CancelCredex(this.repository);

  Future<Either<Failure, void>> call(String credexId) async {
    return await repository.cancelCredex(credexId);
  }
}
