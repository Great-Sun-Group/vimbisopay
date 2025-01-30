import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vimbisopay_app/infrastructure/services/notification_service.dart';
import 'package:vimbisopay_app/main.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _notificationStatus = 'Checking...';
  String _fcmToken = 'Unknown';
  String _lastNotification = 'None';
  final NotificationService _notificationService = NotificationService();
  
  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
    _listenForNotifications();
  }

  Future<void> _checkNotificationStatus() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      final token = await FirebaseMessaging.instance.getToken();
      
      setState(() {
        _notificationStatus = '''
Authorization: ${settings.authorizationStatus}
Alert: ${settings.alert}
Badge: ${settings.badge}
Sound: ${settings.sound}
''';
        _fcmToken = token ?? 'Failed to get token';
      });
    } catch (e) {
      setState(() {
        _notificationStatus = 'Error: $e';
      });
    }
  }

  void _listenForNotifications() {
    _notificationService.onNotification.listen((message) {
      setState(() {
        _lastNotification = '''
Title: ${message.notification?.title}
Body: ${message.notification?.body}
Data: ${message.data}
Received at: ${DateTime.now()}
''';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_notificationStatus),
            ),
            const SizedBox(height: 16),
            const Text(
              'FCM Token',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_fcmToken),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last Notification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_lastNotification),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _checkNotificationStatus,
                        child: const Text('Refresh Status'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            // Send a test notification using FCM's own token
                            final token = await FirebaseMessaging.instance.getToken();
                            if (token == null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to get FCM token')),
                                );
                              }
                              return;
                            }

                            // Simulate a notification by directly using the notification service
                            final testMessage = RemoteMessage(
                              notification: RemoteNotification(
                                title: 'Test Notification',
                                body: 'This is a test notification sent at ${DateTime.now()}',
                              ),
                              data: {
                                'type': 'test',
                                'timestamp': DateTime.now().toIso8601String(),
                              },
                              messageId: 'test_${DateTime.now().millisecondsSinceEpoch}',
                            );

                            // Play notification sound
                            await _notificationService.playNotificationSound();
                            
                            // Send test notification
                            try {
                              _notificationService.sendTestNotification(testMessage);
                              print('Test notification sent successfully');
                            } catch (e) {
                              print('Error sending test notification: $e');
                              rethrow;
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Test notification sent')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Send Test'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      // Simulate a background message
                      final testMessage = RemoteMessage(
                        notification: RemoteNotification(
                          title: 'Background Test',
                          body: 'This is a background test notification sent at ${DateTime.now()}',
                        ),
                        data: {
                          'type': 'background_test',
                          'timestamp': DateTime.now().toIso8601String(),
                        },
                        messageId: 'background_test_${DateTime.now().millisecondsSinceEpoch}',
                      );

                      // Call background handler directly
                      print('Testing background handler...');
                      await firebaseMessagingBackgroundHandler(testMessage);
                      print('Background handler test complete');

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Background test notification sent')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Background test error: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Test Background Handler'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
