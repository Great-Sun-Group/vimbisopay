class LedgerEntry {
  final String credexID;
  final DateTime timestamp;
  final String type;
  final double amount;
  final String denomination;
  final String description;
  final String counterpartyAccountName;
  final String formattedAmount;
  final String accountId;
  final String accountName;

  // Computed unique identifier that combines multiple fields
  String get uniqueIdentifier => '${accountId}_${timestamp.millisecondsSinceEpoch}_${counterpartyAccountName.replaceAll(' ', '')}_${amount.toString()}_$type';

  LedgerEntry({
    required this.credexID,
    required this.timestamp,
    required this.type,
    required this.amount,
    required this.denomination,
    required this.description,
    required this.counterpartyAccountName,
    required this.formattedAmount,
    required this.accountId,
    required this.accountName,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json, {required String accountId, required String accountName}) {
    // Validate required fields
    if (!json.containsKey('credexID')) {
      throw FormatException('Missing credexID in ledger entry');
    }
    if (!json.containsKey('timestamp')) {
      throw FormatException('Missing timestamp in ledger entry');
    }
    if (!json.containsKey('type')) {
      throw FormatException('Missing type in ledger entry');
    }
    if (!json.containsKey('amount')) {
      throw FormatException('Missing amount in ledger entry');
    }
    if (!json.containsKey('denomination')) {
      throw FormatException('Missing denomination in ledger entry');
    }
    if (!json.containsKey('description')) {
      throw FormatException('Missing description in ledger entry');
    }
    if (!json.containsKey('counterpartyAccountName')) {
      throw FormatException('Missing counterpartyAccountName in ledger entry');
    }
    if (!json.containsKey('formattedAmount')) {
      throw FormatException('Missing formattedAmount in ledger entry');
    }

    final timestamp = json['timestamp'];
    DateTime parsedTimestamp;

    try {
      if (timestamp is Map<String, dynamic> && 
          timestamp.containsKey('year') && 
          timestamp.containsKey('month') && 
          timestamp.containsKey('day') && 
          timestamp.containsKey('hour') && 
          timestamp.containsKey('minute') && 
          timestamp.containsKey('second')) {
        // Handle nested timestamp structure
        parsedTimestamp = DateTime(
          _getLowValue(timestamp['year']),
          _getLowValue(timestamp['month']),
          _getLowValue(timestamp['day']),
          _getLowValue(timestamp['hour']),
          _getLowValue(timestamp['minute']),
          _getLowValue(timestamp['second']),
        );
      } else if (timestamp is String) {
        // Handle ISO string timestamp
        parsedTimestamp = DateTime.parse(timestamp);
      } else {
        throw FormatException('Invalid timestamp format');
      }
    } catch (e) {
      throw FormatException('Error parsing timestamp: $e');
    }

    double parsedAmount;
    try {
      if (json['amount'] is String) {
        parsedAmount = double.parse(json['amount']);
      } else if (json['amount'] is num) {
        parsedAmount = (json['amount'] as num).toDouble();
      } else {
        throw FormatException('Invalid amount format');
      }
    } catch (e) {
      throw FormatException('Error parsing amount: $e');
    }

    return LedgerEntry(
      credexID: json['credexID'].toString(),
      timestamp: parsedTimestamp,
      type: json['type'].toString(),
      amount: parsedAmount,
      denomination: json['denomination'].toString(),
      description: json['description'].toString(),
      counterpartyAccountName: json['counterpartyAccountName'].toString(),
      formattedAmount: json['formattedAmount'].toString(),
      accountId: accountId,
      accountName: accountName,
    );
  }

  static int _getLowValue(dynamic field) {
    if (field is Map<String, dynamic> && field.containsKey('low')) {
      return field['low'] as int;
    } else if (field is int) {
      return field;
    } else {
      throw FormatException('Invalid timestamp field format');
    }
  }
}
