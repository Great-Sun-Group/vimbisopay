class LedgerEntry {
  final String credexID;
  final DateTime timestamp;
  final String type;
  final double amount;
  final String denomination;
  final String description;
  final String counterpartyAccountName;
  final String formattedAmount;

  LedgerEntry({
    required this.credexID,
    required this.timestamp,
    required this.type,
    required this.amount,
    required this.denomination,
    required this.description,
    required this.counterpartyAccountName,
    required this.formattedAmount,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    final timestamp = json['timestamp'];
    return LedgerEntry(
      credexID: json['credexID'],
      timestamp: DateTime(
        timestamp['year']['low'],
        timestamp['month']['low'],
        timestamp['day']['low'],
        timestamp['hour']['low'],
        timestamp['minute']['low'],
        timestamp['second']['low'],
      ),
      type: json['type'],
      amount: double.parse(json['amount']),
      denomination: json['denomination'],
      description: json['description'],
      counterpartyAccountName: json['counterpartyAccountName'],
      formattedAmount: json['formattedAmount'],
    );
  }
}
