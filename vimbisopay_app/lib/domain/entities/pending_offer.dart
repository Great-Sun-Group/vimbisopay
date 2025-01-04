class PendingOffer {
  final String credexID;
  final String counterpartyAccountName;
  final String formattedInitialAmount;
  final bool secured;

  PendingOffer({
    required this.credexID,
    required this.counterpartyAccountName,
    required this.formattedInitialAmount,
    required this.secured,
  });

  factory PendingOffer.fromMap(Map<String, dynamic> map) {
    return PendingOffer(
      credexID: map['credexID'] as String,
      counterpartyAccountName: map['counterpartyAccountName'] as String,
      formattedInitialAmount: map['formattedInitialAmount'] as String,
      secured: map['secured'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'credexID': credexID,
      'counterpartyAccountName': counterpartyAccountName,
      'formattedInitialAmount': formattedInitialAmount,
      'secured': secured,
    };
  }
}
