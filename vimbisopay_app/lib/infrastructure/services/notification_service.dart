import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  
  // Stream controller for notification events
  StreamController<RemoteMessage>? _notificationController;
  Stream<RemoteMessage> get onNotification => 
      _notificationController?.stream ?? 
      (throw StateError('NotificationService not initialized'));

  // For testing purposes only
  void sendTestNotification(RemoteMessage message) {
    if (!_isInitialized || _notificationController == null) {
      throw StateError('NotificationService not initialized');
    }
    _notificationController!.add(message);
  }

  bool _isInitialized = false;

  Future<void> cleanup() async {
    Logger.data('Cleaning up notification service');
    try {
      // Cancel message subscriptions
      await _foregroundMessageSubscription?.cancel();
      await _tokenRefreshSubscription?.cancel();
      
      // Close stream controller if it exists
      await _notificationController?.close();
      
      // Reset initialization flag
      _isInitialized = false;
      
      Logger.state('Notification service cleanup completed');
    } catch (e, stackTrace) {
      Logger.error('Error during notification service cleanup', e, stackTrace);
      // Reset initialization flag even if cleanup fails
      _isInitialized = false;
    }
  }

  Future<void> playNotificationSound() async {
    try {
      // Create a new audio player instance for each sound
      final player = AudioPlayer();
      await player.play(AssetSource('audio/success.mp3'));
      Logger.data('Playing notification sound');
      
      // Dispose the player after the sound finishes
      player.onPlayerComplete.listen((_) async {
        await player.dispose();
      });
    } catch (e, stackTrace) {
      Logger.error('''
Failed to play notification sound:
- Error: $e
- Stack trace: $stackTrace
''');
    }
  }
  
  Future<bool> initialize() async {
    try {
      // Always cleanup and reinitialize to ensure fresh state
      await cleanup();
      _isInitialized = true;
      
      // Create new stream controller
      _notificationController = StreamController<RemoteMessage>.broadcast();

      Logger.data('Starting notification service initialization');

      // Check current permission status first
      final initialSettings = await _firebaseMessaging.getNotificationSettings();
      Logger.data('Initial notification settings: ${initialSettings.authorizationStatus}');
      
      // Always request permissions to ensure they're current
      Logger.data('Requesting notification permissions...');
      final NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );
      
      Logger.data('Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        Logger.error('Notification permissions denied by user');
        return false;
      }

      // Configure foreground notification presentation options
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Try to get FCM token
      String? token;
      if (Platform.isIOS) {
        Logger.data('iOS platform detected, waiting for APNS token...');
        // Wait for APNS token to be set
        int retries = 0;
        while (retries < 5) {
          final apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null) {
            Logger.data('APNS token received: ${apnsToken.length} chars');
            token = await _firebaseMessaging.getToken();
            if (token != null) {
              break;
            }
          }
          retries++;
          Logger.data('APNS token not available, retry $retries of 5');
          await Future.delayed(const Duration(seconds: 1));
        }
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

      // Set up message handlers for foreground messages
      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        try {
          print('=== NOTIFICATION RECEIVED ===');
          print('Message ID: ${message.messageId}');
          print('Title: ${message.notification?.title}');
          print('Body: ${message.notification?.body}');
          print('Data: ${message.data}');
          print('Category: ${message.category}');
          print('SenderId: ${message.senderId}');
          print('ThreadId: ${message.threadId}');
          print('From: ${message.from}');
          print('SentTime: ${message.sentTime}');

          // Check if notification controller exists
          if (_notificationController == null) {
            print('ERROR: NotificationController is null');
            return;
          }

          if (!_isInitialized) {
            print('ERROR: NotificationService not initialized');
            return;
          }

          // Create a new message with the same data
          final processedMessage = RemoteMessage(
            notification: message.notification,
            data: Map<String, String>.from(message.data),
            messageId: message.messageId,
            senderId: message.senderId,
            category: message.category,
            from: message.from,
            sentTime: message.sentTime,
            threadId: message.threadId,
          );

          try {
            // Play notification sound
            print('Playing notification sound...');
            await playNotificationSound();
            Logger.data('Notification sound played');

            // Emit message to trigger UI refresh and show toast
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

          // Log notification settings
          _firebaseMessaging.getNotificationSettings().then((settings) {
            Logger.data('''
Current notification settings:
- Authorization Status: ${settings.authorizationStatus}
- Alert Setting: ${settings.alert}
- Badge Setting: ${settings.badge}
- Sound Setting: ${settings.sound}
- Announcement Setting: ${settings.announcement}
- CarPlay Setting: ${settings.carPlay}
- CriticalAlert Setting: ${settings.criticalAlert}
''');
          });
        } catch (e, stackTrace) {
          Logger.error('Error processing foreground message', e, stackTrace);
        }
      }, onError: (error) {
        Logger.error('Error in foreground message stream', error);
      });

      Logger.data('Foreground message handler setup complete');

      // Set up token refresh handler
      _tokenRefreshSubscription = _firebaseMessaging.onTokenRefresh.listen((newToken) {
        Logger.data('FCM token refreshed');
      });

      // Set up message open handler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        Logger.data('''
🔔 App opened from notification:
- Message ID: ${message.messageId}
- Title: ${message.notification?.title}
- Body: ${message.notification?.body}
- Data: ${message.data}
''');
        _notificationController?.add(message);
      });

      Logger.data('Notification service initialized successfully');
      return true;
    } catch (e, stackTrace) {
      Logger.error('''
Failed to initialize Firebase Messaging:
- Error: $e
- Stack trace: $stackTrace
''');
      return false;
    }
  }

  final String baseUrl = ApiConfig.baseUrl;

  Future<bool> registerToken(String token, String authToken) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    final url = '$baseUrl/api/notifications/register-token';
    final body = {
      'token': token,
      'platform': platform,
    };

    Logger.data('''
Registering notification token:
- Platform: $platform
- URL: $url
- Token length: ${token.length}
''');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        Logger.data('''
Successfully registered notification token:
- Status code: ${response.statusCode}
- Response: ${response.body}
''');
        return true;
      } else {
        Logger.error('''
Failed to register notification token:
- Status code: ${response.statusCode}
- Response: ${response.body}
- Request body: ${json.encode(body)}
''');
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('''
Error registering notification token:
- Error: $e
- Stack trace: $stackTrace
- Platform: $platform
- URL: $url
- Request body: ${json.encode(body)}
''');
      return false;
    }
  }
}
