import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';

/// Use case for retrieving a member's dashboard by phone number
class GetMemberDashboard {
  final AccountRepository repository;

  GetMemberDashboard(this.repository);

  /// Execute the use case
  /// Returns Either a Failure or the Dashboard
  Future<Either<Failure, Dashboard>> execute(String phone) async {
    if (phone.isEmpty) {
      return Left(DomainFailure('Phone number cannot be empty'));
    }
    
    // Basic phone number validation
    if (!RegExp(r'^\+?[\d\s-]+$').hasMatch(phone)) {
      return Left(DomainFailure('Invalid phone number format'));
    }

    return repository.getMemberDashboardByPhone(phone);
  }
}
