class CredexRequest {
  final String issuerAccountID;
  final String receiverAccountID;
  final String denomination;
  final double initialAmount;
  final String credexType;
  final String offersOrRequests;
  final bool securedCredex;
  final String? dueDate;
  final String? invoiceID;

  /// Creates a new [CredexRequest] instance.
  ///
  /// [dueDate] defaults to 30 days from now if not provided.
  /// [invoiceID] is optional and can be null.
  CredexRequest({
    required this.issuerAccountID,
    required this.receiverAccountID,
    required this.denomination,
    required this.initialAmount,
    required this.credexType,
    required this.offersOrRequests,
    required this.securedCredex,
    this.dueDate,
    this.invoiceID,
  });


  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'issuerAccountID': issuerAccountID,
      'receiverAccountID': receiverAccountID,
      'Denomination': denomination,
      'InitialAmount': initialAmount,
      'credexType': credexType,
      'OFFERSorREQUESTS': offersOrRequests,
      'securedCredex': securedCredex,
      'dueDate': dueDate,
    };
    
    // Only add invoiceID if it's not null
    if (invoiceID != null) {
      json['invoiceID'] = invoiceID;
    }
    
    return json;
  }
}
