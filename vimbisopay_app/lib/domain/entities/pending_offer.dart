import 'package:vimbisopay_app/domain/entities/dashboard.dart' show CreditRating;

class PendingOffer {
  final String credexID;
  final String counterpartyAccountName;
  final String formattedInitialAmount;
  final bool secured;
  final CreditRating? counterpartyCreditRating;

  PendingOffer({
    required this.credexID,
    required this.counterpartyAccountName,
    required this.formattedInitialAmount,
    required this.secured,
    this.counterpartyCreditRating,
  });

  factory PendingOffer.fromMap(Map<String, dynamic> map) {
    // Parse counterpartyCreditRating if available
    CreditRating? counterpartyCreditRating;
    if (map.containsKey('counterpartyCreditRating') && map['counterpartyCreditRating'] != null) {
      counterpartyCreditRating = CreditRating.fromMap(map['counterpartyCreditRating'] as Map<String, dynamic>);
    }
    
    return PendingOffer(
      credexID: map['credexID'] as String,
      counterpartyAccountName: map['counterpartyAccountName'] as String,
      formattedInitialAmount: map['formattedInitialAmount'] as String,
      secured: map['secured'] as bool,
      counterpartyCreditRating: counterpartyCreditRating,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'credexID': credexID,
      'counterpartyAccountName': counterpartyAccountName,
      'formattedInitialAmount': formattedInitialAmount,
      'secured': secured,
      'counterpartyCreditRating': counterpartyCreditRating?.toMap(),
    };
  }
}
