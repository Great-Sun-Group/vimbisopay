class CredexRequest {
  final String issuerAccountID;
  final String receiverAccountID;
  final String denomination;
  final double initialAmount;
  final String credexType;
  final String offersOrRequests;
  final bool securedCredex;

  CredexRequest({
    required this.issuerAccountID,
    required this.receiverAccountID,
    required this.denomination,
    required this.initialAmount,
    required this.credexType,
    required this.offersOrRequests,
    required this.securedCredex,
  });

  Map<String, dynamic> toJson() {
    return {
      'issuerAccountID': issuerAccountID,
      'receiverAccountID': receiverAccountID,
      'Denomination': denomination,
      'InitialAmount': initialAmount,
      'credexType': credexType,
      'OFFERSorREQUESTS': offersOrRequests,
      'securedCredex': securedCredex,
    };
  }
}
