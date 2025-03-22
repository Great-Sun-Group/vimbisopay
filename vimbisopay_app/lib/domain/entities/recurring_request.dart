class RecurringRequest {
  final String sourceAccountID;
  final String templateType;
  final int payFrequency;
  final String startDate;
  final int duration;
  final double amount;
  final String denomination;
  final bool securedCredex;
  final double DCOgiveInCXX;
  final String DCOdenom;
  final int memberTier;

  RecurringRequest({
    required this.sourceAccountID,
    required this.templateType,
    required this.payFrequency,
    required this.startDate,
    required this.duration,
    required this.amount,
    required this.denomination,
    required this.securedCredex,
    required this.DCOgiveInCXX,
    required this.DCOdenom,
    required this.memberTier,
  });

  Map<String, dynamic> toJson() {
    return {
      'sourceAccountID': sourceAccountID,
      'templateType': templateType,
      'payFrequency': payFrequency,
      'startDate': startDate,
      'duration': duration,
      'amount': amount,
      'denomination': denomination,
      'securedCredex': securedCredex,
      'DCOgiveInCXX': DCOgiveInCXX,
      'DCOdenom': DCOdenom,
      'memberTier': memberTier,
    };
  }
}
