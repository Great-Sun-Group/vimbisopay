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
      throw const FormatException('Missing credexID in ledger entry');
    }
    if (!json.containsKey('timestamp')) {
      throw const FormatException('Missing timestamp in ledger entry');
    }
    if (!json.containsKey('type')) {
      throw const FormatException('Missing type in ledger entry');
    }
    if (!json.containsKey('amount')) {
      throw const FormatException('Missing amount in ledger entry');
    }
    if (!json.containsKey('denomination')) {
      throw const FormatException('Missing denomination in ledger entry');
    }
    if (!json.containsKey('description')) {
      throw const FormatException('Missing description in ledger entry');
    }
    if (!json.containsKey('counterpartyAccountName')) {
      throw const FormatException('Missing counterpartyAccountName in ledger entry');
    }

    final timestamp = json['timestamp'];
    DateTime parsedTimestamp;

    try {
      if (timestamp is Map<String, dynamic>) {
        if (timestamp.containsKey('year') &&
            timestamp.containsKey('month') &&
            timestamp.containsKey('day') &&
            timestamp.containsKey('hour') &&
            timestamp.containsKey('minute') &&
            timestamp.containsKey('second')) {
          
          // Extract values from the nested low/high structure
          final year = (timestamp['year'] as Map<String, dynamic>)['low'] as int;
          final month = (timestamp['month'] as Map<String, dynamic>)['low'] as int;
          final day = (timestamp['day'] as Map<String, dynamic>)['low'] as int;
          final hour = (timestamp['hour'] as Map<String, dynamic>)['low'] as int;
          final minute = (timestamp['minute'] as Map<String, dynamic>)['low'] as int;
          final second = (timestamp['second'] as Map<String, dynamic>)['low'] as int;

          parsedTimestamp = DateTime(
            year,
            month,
            day,
            hour,
            minute,
            second,
          );
        } else {
          throw const FormatException('Missing required timestamp fields');
        }
      } else if (timestamp is String) {
        // Handle ISO string timestamp
        parsedTimestamp = DateTime.parse(timestamp);
      } else {
        throw const FormatException('Invalid timestamp format');
      }
    } catch (e) {
      throw FormatException('Error parsing timestamp: $e');
    }

    double parsedAmount;
    try {
      if (json['amount'] is String) {
        final amountStr = json['amount'].toString();
        if (amountStr == 'NaN') {
          // Handle NaN case by defaulting to 0.0
          parsedAmount = 0.0;
        } else {
          parsedAmount = double.parse(amountStr);
        }
      } else if (json['amount'] is num) {
        parsedAmount = (json['amount'] as num).toDouble();
      } else {
        throw const FormatException('Invalid amount format');
      }
    } catch (e) {
      // If parsing fails for any reason, default to 0.0
      parsedAmount = 0.0;
    }

    // Format amount if formattedAmount is missing or invalid
    String formattedAmount;
    try {
      if (json.containsKey('formattedAmount') && json['formattedAmount'] != null && json['formattedAmount'].toString().isNotEmpty) {
        formattedAmount = json['formattedAmount'].toString();
      } else {
        // Format the amount with 2 decimal places and add denomination
        final sign = parsedAmount >= 0 ? '+' : '';
        formattedAmount = '$sign${parsedAmount.toStringAsFixed(2)} ${json['denomination']}';
      }
    } catch (e) {
      // Fallback formatting if there's any error
      final sign = parsedAmount >= 0 ? '+' : '';
      formattedAmount = '$sign${parsedAmount.toStringAsFixed(2)} ${json['denomination']}';
    }

    return LedgerEntry(
      credexID: json['credexID'].toString(),
      timestamp: parsedTimestamp,
      type: json['type'].toString(),
      amount: parsedAmount,
      denomination: json['denomination'].toString(),
      description: json['description'].toString(),
      counterpartyAccountName: json['counterpartyAccountName'].toString(),
      formattedAmount: formattedAmount,
      accountId: accountId,
      accountName: accountName,
    );
  }
}
