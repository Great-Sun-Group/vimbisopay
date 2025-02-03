import 'package:vimbisopay_app/domain/entities/recurring_request.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';

class UpgradeMemberTier {
  final AccountRepository repository;

  UpgradeMemberTier(this.repository);

  Future<void> call(String sourceAccountId) async {
    final request = RecurringRequest(
      sourceAccountID: sourceAccountId,
      templateType: 'MEMBERTIER_SUBSCRIPTION',
      payFrequency: 28,
      startDate: DateTime.now().toIso8601String().split('T')[0], // Current date in YYYY-MM-DD format
      duration: 1,
      amount: 1.0,
      denomination: 'USD',
      securedCredex: true,
      DCOgiveInCXX: 0.0,
      DCOdenom: 'USD',
      memberTier: 3,
    );

    await repository.createRecurring(request);
  }
}
