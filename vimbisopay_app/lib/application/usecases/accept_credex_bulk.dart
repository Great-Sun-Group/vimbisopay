import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';

class AcceptCredexBulk {
  final AccountRepository repository;

  AcceptCredexBulk(this.repository);

  Future<Either<Failure, bool>> call(List<String> credexIds) async {
    return await repository.acceptCredexBulk(credexIds);
  }
}
