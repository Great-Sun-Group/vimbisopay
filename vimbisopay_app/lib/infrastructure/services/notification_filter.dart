import 'package:vimbisopay_app/infrastructure/services/storage/storage_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vimbisopay_app/domain/entities/notification_preferences.dart';
import 'dart:convert';

class NotificationFilter {
  static const String _prefsKey = 'notification_preferences';
  final StorageService _storage;

  NotificationFilter(this._storage);

  Future<bool> shouldShowNotification(RemoteMessage message) async {
    final prefsJson = await _storage.getString(_prefsKey);
    print('Notification Filter - Message Data: ${message.data}');
    print('Notification Filter - Type: ${message.data['type']}');
    
    if (prefsJson == null) {
      print('Notification Filter - No preferences found, showing notification');
      return true; // Default to showing notifications if preferences aren't set
    }

    try {
      print('Notification Filter - Preferences JSON: $prefsJson');
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
    final type = (data['type'] ?? 'unknown').toUpperCase().trim();
    print('Notification Filter - Getting notification type: $type');
    print('Notification Filter - Raw data: $data');
    return type;
  }

  bool _checkNotificationTypeEnabled(
    NotificationPreferences preferences,
    String type,
  ) {
    print('Notification Filter - Checking if type is enabled: $type');
    switch (type) {
      case 'MONEY_SENT':
        return preferences.moneyTransfersSent;
      case 'MONEY_RECEIVED':
      case 'OFFER_CREATED':  // Map OFFER_CREATED to money received preference
        return preferences.moneyTransfersReceived;
      case 'TRANSFER_FAILED':
        return preferences.transferFailures;
      case 'BALANCE_UPDATE':
        return preferences.balanceUpdates;
      case 'LIMIT_CHANGE':
        return preferences.accountLimits;
      case 'SECURITY_ALERT':
        return preferences.securityAlerts;
      case 'SERVICE_UPDATE':
        return preferences.serviceUpdates;
      case 'APP_UPDATE':
        return preferences.appUpdates;
      case 'NEW_FEATURE':
        return preferences.newFeatures;
      default:
        return true; // Show unknown notification types by default
    }
  }

  Future<bool> shouldHidePreviewContent() async {
    final prefsJson = await _storage.getString(_prefsKey);
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

  Future<String> formatNotificationContent(RemoteMessage message) async {
    if (!(await shouldHidePreviewContent())) {
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
