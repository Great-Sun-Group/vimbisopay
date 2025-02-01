import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/notification_filter.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final player = AudioPlayer();
  bool _isInitialized = false;
  StreamController<RemoteMessage>? _notificationController;
  StreamSubscription? _tokenRefreshSubscription;
  late final NotificationFilter _notificationFilter;

  // Stream for notification events
  Stream<RemoteMessage> get onNotification =>
      _notificationController?.stream ??
      (throw StateError('NotificationService not initialized'));

  void sendTestNotification(RemoteMessage message) {
    if (!_isInitialized || _notificationController == null) {
      throw StateError('NotificationService not initialized');
    }
    _notificationController!.add(message);
  }

  Future<void> cleanup() async {
    Logger.data('Cleaning up notification service');
    try {
      // Close stream controller if it exists
      await _notificationController?.close();
      await _tokenRefreshSubscription?.cancel();
    } catch (e, stackTrace) {
      Logger.error('Error during notification service cleanup', e, stackTrace);
    } finally {
      _isInitialized = false;
    }
  }

  Future<void> playNotificationSound() async {
    try {
      await player.play(AssetSource('audio/success.mp3'));
      Logger.data('Playing notification sound');
    } catch (e) {
      Logger.error('''
Failed to play notification sound:
- Error: $e
''');
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      // Create new stream controller
      _notificationController = StreamController<RemoteMessage>.broadcast();

      Logger.data('Starting notification service initialization');

      // Initialize notification filter
      final prefs = await SharedPreferences.getInstance();
      _notificationFilter = NotificationFilter(prefs);

      final initialSettings = await _firebaseMessaging.getNotificationSettings();
      Logger.data('Initial notification settings: ${initialSettings.authorizationStatus}');

      // Always request permissions to ensure they're current
      Logger.data('Requesting notification permissions...');
      final NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Configure foreground notification presentation options
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Try to get FCM token
      String? token;
      if (Platform.isIOS) {
        // For iOS, wait for APNS token to be set
        token = await _firebaseMessaging.getToken();
      } else {
        // For Android, directly get FCM token
        token = await _firebaseMessaging.getToken();
      }

      if (token == null) {
        final error = Platform.isIOS ? 'Failed to obtain FCM Token (APNS token not set)' : 'Failed to obtain FCM Token';
        Logger.error(error);
        return false;
      }

      Logger.data('FCM Token obtained successfully');

      // Set up message handlers
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        try {
          print('Message ID: ${message.messageId}');
          print('Title: ${message.notification?.title}');
          print('Body: ${message.notification?.body}');
          print('Data: ${message.data}');

          // Check if notification should be shown based on user preferences
          if (!await _notificationFilter.shouldShowNotification(message)) {
            Logger.data('Notification filtered out based on user preferences');
            return;
          }

          // Format notification content based on privacy settings
          final formattedBody = _notificationFilter.formatNotificationContent(message);
          final processedMessage = RemoteMessage(
            messageId: message.messageId,
            notification: RemoteNotification(
              title: message.notification?.title,
              body: formattedBody,
            ),
            data: Map<String, String>.from(message.data),
          );

          // Play notification sound
          print('Playing notification sound...');
          await playNotificationSound();

          print('Broadcasting message to stream...');
          if (_notificationController == null) {
            Logger.error('NotificationController is null when trying to broadcast message');
            return;
          }

          Logger.data('About to broadcast message with details:');
          Logger.data('Title: ${processedMessage.notification?.title}');
          Logger.data('Body: ${processedMessage.notification?.body}');
          Logger.data('Data: ${processedMessage.data}');

          _notificationController!.add(processedMessage);
          Logger.data('Message broadcast complete');

          // Verify stream has listeners
          final hasListeners = _notificationController!.hasListener;
          Logger.data('Stream has listeners: $hasListeners');
        } catch (e, stackTrace) {
          Logger.error('Error in notification broadcast', e, stackTrace);
        }
      });

      // Log notification settings
      _firebaseMessaging.getNotificationSettings().then((settings) {
        Logger.data('''
Current notification settings:
- Authorization Status: ${settings.authorizationStatus}
''');
      });

      // Set up token refresh listener
      _tokenRefreshSubscription = _firebaseMessaging.onTokenRefresh.listen((newToken) {
        Logger.data('FCM token refreshed');
        _registerToken(newToken);
      });

      // Handle notification open events
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        Logger.data('''
🔔 App opened from notification:
- Message ID: ${message.messageId}
- Title: ${message.notification?.title}
- Body: ${message.notification?.body}
- Data: ${message.data}
''');
        _notificationController?.add(message);
      });

      _isInitialized = true;
      return true;
    } catch (e, stackTrace) {
      Logger.error('Error initializing notification service', e, stackTrace);
      return false;
    }
  }

  Future<void> _registerToken(String token) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    final url = '${ApiConfig.baseUrl}/api/notifications/register-token';
    final body = {
      'token': token,
      'platform': platform,
    };

    Logger.data('''
Registering notification token:
- Platform: $platform
''');

    try {
      final response = await http.post(
        Uri.parse(url),
        body: body,
      );

      if (response.statusCode == 200) {
        Logger.data('''
Successfully registered notification token:
- Status code: ${response.statusCode}
''');
      } else {
        Logger.error('''
Failed to register notification token:
- Status code: ${response.statusCode}
''');
      }
    } catch (e) {
      Logger.error('''
Error registering notification token:
- Error: $e
''');
    }
  }
}
