import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vimbisopay_app/domain/entities/notification_preferences.dart';
import 'dart:convert';

class NotificationFilter {
  static const String _prefsKey = 'notification_preferences';
  final SharedPreferences _prefs;

  NotificationFilter(this._prefs);

  Future<bool> shouldShowNotification(RemoteMessage message) async {
    final prefsJson = _prefs.getString(_prefsKey);
    if (prefsJson == null) {
      return true; // Default to showing notifications if preferences aren't set
    }

    try {
      final preferences = NotificationPreferences.fromJson(
        Map<String, dynamic>.from(jsonDecode(prefsJson)),
      );

      if (!preferences.masterEnabled) {
        return false;
      }

      final notificationType = _getNotificationType(message);
      return _checkNotificationTypeEnabled(preferences, notificationType);
    } catch (e) {
      return true; // Default to showing notifications if there's an error
    }
  }

  String _getNotificationType(RemoteMessage message) {
    final data = message.data;
    return data['type'] ?? 'unknown';
  }

  bool _checkNotificationTypeEnabled(
    NotificationPreferences preferences,
    String type,
  ) {
    switch (type.toLowerCase()) {
      case 'money_sent':
        return preferences.moneyTransfersSent;
      case 'money_received':
        return preferences.moneyTransfersReceived;
      case 'transfer_failed':
        return preferences.transferFailures;
      case 'balance_update':
        return preferences.balanceUpdates;
      case 'limit_change':
        return preferences.accountLimits;
      case 'security_alert':
        return preferences.securityAlerts;
      case 'service_update':
        return preferences.serviceUpdates;
      case 'app_update':
        return preferences.appUpdates;
      case 'new_feature':
        return preferences.newFeatures;
      default:
        return true; // Show unknown notification types by default
    }
  }

  bool shouldHidePreviewContent() {
    final prefsJson = _prefs.getString(_prefsKey);
    if (prefsJson == null) {
      return false;
    }

    try {
      final preferences = NotificationPreferences.fromJson(
        Map<String, dynamic>.from(jsonDecode(prefsJson)),
      );
      return preferences.hidePreviewContent;
    } catch (e) {
      return false;
    }
  }

  String formatNotificationContent(RemoteMessage message) {
    if (!shouldHidePreviewContent()) {
      return message.notification?.body ?? '';
    }

    // Hide sensitive information in preview
    final type = _getNotificationType(message);
    switch (type.toLowerCase()) {
      case 'money_sent':
      case 'money_received':
      case 'balance_update':
        return 'New transaction notification';
      case 'transfer_failed':
        return 'Transaction status update';
      case 'limit_change':
        return 'Account limit update';
      case 'security_alert':
        return 'Security notification';
      default:
        return message.notification?.body ?? '';
    }
  }
}
