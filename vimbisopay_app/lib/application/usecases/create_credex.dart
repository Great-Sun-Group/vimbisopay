import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';

class CreateCredex {
  final AccountRepository repository;

  CreateCredex(this.repository);

  Future<Either<Failure, CredexResponse>> execute(CredexRequest request) async {
    return await repository.createCredex(request);
  }
}
