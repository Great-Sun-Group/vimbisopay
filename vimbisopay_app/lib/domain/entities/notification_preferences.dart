import 'package:equatable/equatable.dart';

class NotificationPreferences extends Equatable {
  final bool masterEnabled;
  final bool moneyTransfersSent;
  final bool moneyTransfersReceived;
  final bool transferFailures;
  final bool balanceUpdates;
  final bool accountLimits;
  final bool securityAlerts;
  final bool serviceUpdates;
  final bool appUpdates;
  final bool newFeatures;
  final bool quietHoursEnabled;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final bool hidePreviewContent;

  const NotificationPreferences({
    this.masterEnabled = true,
    this.moneyTransfersSent = true,
    this.moneyTransfersReceived = true,
    this.transferFailures = true,
    this.balanceUpdates = true,
    this.accountLimits = true,
    this.securityAlerts = true,
    this.serviceUpdates = true,
    this.appUpdates = true,
    this.newFeatures = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.hidePreviewContent = false,
  });

  @override
  List<Object?> get props => [
        masterEnabled,
        moneyTransfersSent,
        moneyTransfersReceived,
        transferFailures,
        balanceUpdates,
        accountLimits,
        securityAlerts,
        serviceUpdates,
        appUpdates,
        newFeatures,
        hidePreviewContent,
      ];

  NotificationPreferences copyWith({
    bool? masterEnabled,
    bool? moneyTransfersSent,
    bool? moneyTransfersReceived,
    bool? transferFailures,
    bool? balanceUpdates,
    bool? accountLimits,
    bool? securityAlerts,
    bool? serviceUpdates,
    bool? appUpdates,
    bool? newFeatures,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? hidePreviewContent,
  }) {
    return NotificationPreferences(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      moneyTransfersSent: moneyTransfersSent ?? this.moneyTransfersSent,
      moneyTransfersReceived: moneyTransfersReceived ?? this.moneyTransfersReceived,
      transferFailures: transferFailures ?? this.transferFailures,
      balanceUpdates: balanceUpdates ?? this.balanceUpdates,
      accountLimits: accountLimits ?? this.accountLimits,
      securityAlerts: securityAlerts ?? this.securityAlerts,
      serviceUpdates: serviceUpdates ?? this.serviceUpdates,
      appUpdates: appUpdates ?? this.appUpdates,
      newFeatures: newFeatures ?? this.newFeatures,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      hidePreviewContent: hidePreviewContent ?? this.hidePreviewContent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'masterEnabled': masterEnabled,
      'moneyTransfersSent': moneyTransfersSent,
      'moneyTransfersReceived': moneyTransfersReceived,
      'transferFailures': transferFailures,
      'balanceUpdates': balanceUpdates,
      'accountLimits': accountLimits,
      'securityAlerts': securityAlerts,
      'serviceUpdates': serviceUpdates,
      'appUpdates': appUpdates,
      'newFeatures': newFeatures,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'hidePreviewContent': hidePreviewContent,
    };
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      masterEnabled: json['masterEnabled'] ?? true,
      moneyTransfersSent: json['moneyTransfersSent'] ?? true,
      moneyTransfersReceived: json['moneyTransfersReceived'] ?? true,
      transferFailures: json['transferFailures'] ?? true,
      balanceUpdates: json['balanceUpdates'] ?? true,
      accountLimits: json['accountLimits'] ?? true,
      securityAlerts: json['securityAlerts'] ?? true,
      serviceUpdates: json['serviceUpdates'] ?? true,
      appUpdates: json['appUpdates'] ?? true,
      newFeatures: json['newFeatures'] ?? true,
      quietHoursEnabled: json['quietHoursEnabled'] ?? false,
      quietHoursStart: json['quietHoursStart'],
      quietHoursEnd: json['quietHoursEnd'],
      hidePreviewContent: json['hidePreviewContent'] ?? false,
    );
  }
}
