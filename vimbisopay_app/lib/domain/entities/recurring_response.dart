import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dash;

class RecurringResponse {
  final String message;
  final RecurringData data;

  RecurringResponse({
    required this.message,
    required this.data,
  });
}

class RecurringData {
  final RecurringAction action;
  final dash.Dashboard dashboard;

  RecurringData({
    required this.action,
    required this.dashboard,
  });
}

class RecurringAction {
  final String id;
  final String type;
  final String timestamp;
  final String actor;
  final RecurringActionDetails details;

  RecurringAction({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.actor,
    required this.details,
  });
}

class RecurringActionDetails {
  final String recurringID;
  final String amount;
  final String denomination;
  final int payFrequency;
  final NextDate nextDate;
  final String status;

  RecurringActionDetails({
    required this.recurringID,
    required this.amount,
    required this.denomination,
    required this.payFrequency,
    required this.nextDate,
    required this.status,
  });
}

class NextDate {
  final YearValue year;
  final YearValue month;
  final YearValue day;

  NextDate({
    required this.year,
    required this.month,
    required this.day,
  });
}

class YearValue {
  final int low;
  final int high;

  YearValue({
    required this.low,
    required this.high,
  });
}
