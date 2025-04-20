import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/main.dart';
import 'package:vimbisopay_app/presentation/widgets/debug/debug_card.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Tab for managing notifications in the debug screen.
class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  String _notificationStatus = 'Checking...';
  String _fcmToken = 'Unknown';
  String _lastNotification = 'None';
  String _initializationStatus = 'Not initialized';
  final _notificationService = ServiceLocator.notificationService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeNotificationService();
  }

  Future<void> _initializeNotificationService() async {
    try {
      setState(() {
        _initializationStatus = 'Initializing...';
      });

      final initialized = await _notificationService.initialize();
      
      if (initialized) {
        setState(() {
          _isInitialized = true;
          _initializationStatus = 'Initialized successfully';
        });
        
        // Only proceed with these after successful initialization
        await _checkNotificationStatus();
        _listenForNotifications();
      } else {
        setState(() {
          _initializationStatus = 'Initialization failed';
        });
      }
    } catch (e) {
      setState(() {
        _initializationStatus = 'Initialization error: $e';
      });
    }
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
    if (!_isInitialized) return;
    
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notification Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          DebugCard(
            border: _isInitialized 
                ? null 
                : Border.all(color: AppColors.error),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Initialization Status: $_initializationStatus',
                  style: TextStyle(
                    color: _isInitialized ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_notificationStatus),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'FCM Token',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          DebugCard(
            child: SelectableText(_fcmToken),
          ),
          const SizedBox(height: 16),
          const Text(
            'Last Notification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          DebugCard(
            child: Text(_lastNotification),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _checkNotificationStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Status'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        try {
                          if (!_isInitialized) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('NotificationService not initialized'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                            return;
                          }

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
                            notification: const RemoteNotification(
                              title: 'Test Notification',
                              body: 'This is a test notification',
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
                      icon: const Icon(Icons.send),
                      label: const Text('Send Test'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    // Simulate a background message
                    final testMessage = RemoteMessage(
                      notification: const RemoteNotification(
                        title: 'Background Test',
                        body: 'This is a background test notification',
                      ),
                      data: {
                        'type': 'background_test',
                        'timestamp': DateTime.now().toIso8601String(),
                      },
                      messageId: 'background_test_${DateTime.now().millisecondsSinceEpoch}',
                    );

                    if (!_isInitialized) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('NotificationService not initialized'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      return;
                    }

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
                icon: const Icon(Icons.notifications_active),
                label: const Text('Test Background Handler'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.yellowPrimary,
                  foregroundColor: AppColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
