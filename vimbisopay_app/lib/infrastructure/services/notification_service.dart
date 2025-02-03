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
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final player = AudioPlayer();
  bool _isInitialized = false;
  StreamController<RemoteMessage>? _notificationController;
  StreamController<void>? _refreshController;
  StreamSubscription? _tokenRefreshSubscription;
  late final NotificationFilter _notificationFilter;

  // Stream for notification events
  Stream<RemoteMessage> get onNotification =>
      _notificationController?.stream ??
      (throw StateError('NotificationService not initialized'));

  // Stream for refresh events
  Stream<void> get onRefreshNeeded =>
      _refreshController?.stream ??
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
      // Close stream controllers if they exist
      await Future.wait([
        _notificationController?.close() ?? Future.value(),
        _refreshController?.close() ?? Future.value(),
        _tokenRefreshSubscription?.cancel() ?? Future.value(),
      ]);
      
      // Reset controllers
      _notificationController = null;
      _refreshController = null;
      _tokenRefreshSubscription = null;
      
      Logger.data('Successfully cleaned up notification service');
    } catch (e, stackTrace) {
      Logger.error('''
Error during notification service cleanup:
- Error: $e
- Stack trace: $stackTrace
''');
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

  bool _verifyServiceState() {
    final state = {
      'isInitialized': _isInitialized,
      'hasNotificationController': _notificationController != null,
      'hasRefreshController': _refreshController != null,
      'hasNotificationListeners': _notificationController?.hasListener ?? false,
      'hasRefreshListeners': _refreshController?.hasListener ?? false,
    };

    Logger.data('''
Verifying NotificationService state:
- Is initialized: ${state['isInitialized']}
- Has notification controller: ${state['hasNotificationController']}
- Has refresh controller: ${state['hasRefreshController']}
- Has notification listeners: ${state['hasNotificationListeners']}
- Has refresh listeners: ${state['hasRefreshListeners']}
''');

    return state['isInitialized']! &&
           state['hasNotificationController']! &&
           state['hasRefreshController']!;
  }

  Future<bool> initialize() async {
    Logger.data('Initializing NotificationService');
    
    if (_isInitialized) {
      Logger.data('NotificationService already initialized');
      final isValid = _verifyServiceState();
      if (!isValid) {
        Logger.error('Service marked as initialized but state is invalid, reinitializing...');
        await cleanup();
      } else {
        return true;
      }
    }

    try {
      // Create new stream controllers
      _notificationController = StreamController<RemoteMessage>.broadcast();
      _refreshController = StreamController<void>.broadcast();

      Logger.data('''
Created stream controllers:
- Notification controller: ${_notificationController != null}
- Refresh controller: ${_refreshController != null}
''');

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
      Logger.data('Configuring foreground notification presentation options...');
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,    // Show alert
        badge: true,    // Show badge
        sound: true,    // Play sound
      );
      Logger.data('Foreground notification presentation options configured');


      // Try to get FCM token
      String? token;
      Logger.data('''
Attempting to get FCM token:
- Platform: ${Platform.isIOS ? 'iOS' : 'Android'}
- Authorization Status: ${settings.authorizationStatus}
''');

      if (Platform.isIOS) {
        // For iOS, wait for APNS token to be set
        Logger.data('iOS: Getting FCM token (requires APNS token)...');
        token = await _firebaseMessaging.getToken();
      } else {
        // For Android, directly get FCM token
        Logger.data('Android: Getting FCM token...');
        token = await _firebaseMessaging.getToken();
      }

      if (token == null) {
        final error = Platform.isIOS ? 'Failed to obtain FCM Token (APNS token not set)' : 'Failed to obtain FCM Token';
        Logger.error('''
$error
- Platform: ${Platform.isIOS ? 'iOS' : 'Android'}
- Authorization Status: ${settings.authorizationStatus}
- Notification Settings: ${await _firebaseMessaging.getNotificationSettings()}
''');
        return false;
      }

      Logger.data('''
FCM Token obtained successfully:
- Token Length: ${token.length}
- Platform: ${Platform.isIOS ? 'iOS' : 'Android'}
- Authorization Status: ${settings.authorizationStatus}
''');

      // Register the token
      Logger.data('Initiating token registration...');
      await _registerToken(token);

      // Set up message handlers
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        try {
          print('Message ID: ${message.messageId}');
          print('Title: ${message.notification?.title}');
          print('Body: ${message.notification?.body}');
          print('Data: ${message.data}');

          // Check if notification should be shown based on user preferences
          print('NotificationService - Received message type: ${message.data['type']}');
          final shouldShow = await _notificationFilter.shouldShowNotification(message);
          print('NotificationService - Should show notification: $shouldShow');
          if (!shouldShow) {
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
            senderId: message.senderId,
            category: message.category,
            from: message.from,
            sentTime: message.sentTime,
            threadId: message.threadId,
          );

          // Play notification sound
          print('Playing notification sound...');
          await playNotificationSound();

          print('Broadcasting message to stream...');
          if (_notificationController == null || _refreshController == null) {
            Logger.error('Stream controllers are null when trying to broadcast message');
            return;
          }

          Logger.data('About to broadcast message with details:');
          Logger.data('Title: ${processedMessage.notification?.title}');
          Logger.data('Body: ${processedMessage.notification?.body}');
          Logger.data('Data: ${processedMessage.data}');

          // Broadcast the notification
          _notificationController!.add(processedMessage);
          Logger.data('Message broadcast complete');

          // Trigger refresh if this is a transaction-related notification
          final notificationType = processedMessage.data['type']?.toUpperCase().trim();
          print('NotificationService - Processing notification type: $notificationType');
          print('NotificationService - Raw notification data: ${processedMessage.data}');
          Logger.data('''
Processing notification for refresh:
- Type: $notificationType
- Raw Data: ${processedMessage.data}
- Notification Body: ${processedMessage.notification?.body}
''');
          
          final validTypes = [
            'TRANSACTION',
            'CREDEX_OFFER',
            'OFFER_ACCEPTED',
            'CREDEX_ACCEPTED',
            'OFFER_CREATED',
            'OFFER_CANCELLED'
          ];
          
          if (notificationType != null && validTypes.contains(notificationType)) {
            Logger.data('Transaction-related notification received, verifying service state');
            
            if (!_verifyServiceState()) {
              Logger.error('Cannot trigger refresh - invalid service state');
              return;
            }
            
            if (!_refreshController!.hasListener) {
              Logger.error('Cannot trigger refresh - no listeners attached to stream');
              return;
            }
            
            Logger.data('Service state verified, triggering refresh');
            _refreshController!.add(null);
            Logger.data('Refresh event sent to stream successfully');
          } else {
            Logger.data('Notification type does not require refresh: $notificationType');
          }

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
    const url = '${ApiConfig.baseUrl}/api/notifications/register-token';
    final body = {
      'token': token,
      'platform': platform,
    };

    Logger.data('''
Registering notification token:
- Platform: $platform
- URL: $url
- Token Length: ${token.length}
- Request Body: $body
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
- Response body: ${response.body}
- Headers: ${response.headers}
''');
      } else {
        Logger.error('''
Failed to register notification token:
- Status code: ${response.statusCode}
- Response body: ${response.body}
- Headers: ${response.headers}
- Request URL: $url
- Request body: $body
''');
      }
    } catch (e, stackTrace) {
      Logger.error('''
Error registering notification token:
- Error: $e
- Stack trace: $stackTrace
- Request URL: $url
- Request body: $body
''');
    }
  }
}
