import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Future<void> initialize() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      Logger.data('Notification permission status: ${settings.authorizationStatus}');

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        Logger.data('FCM Token obtained');
      }

      // Handle token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        Logger.data('FCM token refreshed');
      });

      // Handle messages when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        Logger.data('Received foreground message: ${message.messageId}');
        _playNotificationSound();
      });
    } catch (e, stackTrace) {
      Logger.error('''
Failed to initialize Firebase Messaging:
- Error: $e
- Stack trace: $stackTrace
''');
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/success.mp3'));
      Logger.data('Playing notification sound');
    } catch (e, stackTrace) {
      Logger.error('''
Failed to play notification sound:
- Error: $e
- Stack trace: $stackTrace
''');
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
