import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/recurring_request.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';

class UpgradeMemberTier {
  final AccountRepository repository;

  UpgradeMemberTier(this.repository);

  Future<void> call(String sourceAccountId) async {
    // Old implementation (kept but not used)
    /*
    final request = RecurringRequest(
      sourceAccountID: sourceAccountId,
      templateType: 'MEMBERTIER_SUBSCRIPTION',
      payFrequency: 28,
      startDate: DateTime.now().toIso8601String().split('T')[0], // Current date in YYYY-MM-DD format
      duration: 1,
      amount: 1.0,
      denomination: 'USD',
      securedCredex: true,
      DCOgiveInCXX: 1.0,
      DCOdenom: 'USD',
      memberTier: 3,
    );

    await repository.createRecurring(request);
    */
    
    // New implementation using the Hustler10k endpoint
    Logger.data('[UPGRADE_MEMBER_TIER] Upgrading member with account ID: $sourceAccountId');
    final result = await repository.upgradeToHustler10k(sourceAccountId);
    
    result.fold(
      (failure) {
        // Preserve error code in the exception message if available
        if (failure is InfrastructureFailure && failure.code != null) {
          throw Exception('Failed to upgrade member: ${failure.message}|code=${failure.code}');
        } else {
          throw Exception('Failed to upgrade member: ${failure.message}');
        }
      },
      (_) => Logger.data('[UPGRADE_MEMBER_TIER] Member upgrade successful'),
    );
  }
}
