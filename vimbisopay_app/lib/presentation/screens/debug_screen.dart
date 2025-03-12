import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:vimbisopay_app/core/config/feature_flags.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vimbisopay_app/main.dart';

/// Debug screen for the VimbisoPay app.
///
/// This screen provides debugging tools for the app, such as forcing a refresh
/// of the Remote Config and viewing the current values of feature flags,
/// as well as testing and debugging push notifications.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> with SingleTickerProviderStateMixin {
  // Tab controller
  late TabController _tabController;
  
  // Feature flags tab variables
  bool _isLoading = false;
  String _statusMessage = '';
  bool _marketplaceEnabled = false;
  String _defaultValue = 'Unknown';
  String _remoteValue = 'Unknown';
  bool _hasLocalOverride = false;
  bool? _localOverrideValue;
  
  // Notifications tab variables
  String _notificationStatus = 'Checking...';
  String _fcmToken = 'Unknown';
  String _lastNotification = 'None';
  String _initializationStatus = 'Not initialized';
  final _notificationService = ServiceLocator.notificationService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentValues();
    _initializeNotificationService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Feature flags methods
  Future<void> _loadCurrentValues() async {
    // Get the remote config instance directly
    final remoteConfig = FirebaseRemoteConfig.instance;
    final featureFlagService = ServiceLocator.featureFlagService;
    
    setState(() {
      _marketplaceEnabled = featureFlagService.isMarketplaceEnabled();
      _defaultValue = FeatureFlags.defaults[FeatureFlags.enableMarketplace].toString();
      _remoteValue = remoteConfig.getValue(FeatureFlags.enableMarketplace).asBool().toString();
      _hasLocalOverride = featureFlagService.hasMarketplaceOverride();
      _localOverrideValue = featureFlagService.getMarketplaceOverrideValue();
    });
  }

  Future<void> _forceRefresh() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Refreshing Remote Config...';
    });

    try {
      final refreshed = await ServiceLocator.featureFlagService.forceRefresh();
      // Get the remote config instance directly
      final remoteConfig = FirebaseRemoteConfig.instance;
      
      setState(() {
        _isLoading = false;
        _statusMessage = refreshed 
            ? 'Remote Config refreshed successfully!' 
            : 'Failed to refresh Remote Config.';
        _marketplaceEnabled = ServiceLocator.featureFlagService.isMarketplaceEnabled();
        _defaultValue = FeatureFlags.defaults[FeatureFlags.enableMarketplace].toString();
        _remoteValue = remoteConfig.getValue(FeatureFlags.enableMarketplace).asBool().toString();
      });
      
      Logger.data('Force refresh result: $refreshed');
      Logger.data('Marketplace feature enabled after refresh: $_marketplaceEnabled');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error refreshing Remote Config: $e';
      });
      Logger.error('Error refreshing Remote Config', e);
    }
  }
  
  // Notification methods
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Tools'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Feature Flags'),
            Tab(text: 'Notifications'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Feature Flags Tab
          _buildFeatureFlagsTab(),
          
          // Notifications Tab
          _buildNotificationsTab(),
        ],
      ),
    );
  }
  
  // Feature Flags Tab
  Widget _buildFeatureFlagsTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Marketplace Feature',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Switch(
                          value: _marketplaceEnabled,
                          onChanged: _isLoading ? null : (value) async {
                            setState(() {
                              _isLoading = true;
                              _statusMessage = 'Setting local override...';
                            });
                            
                            try {
                              final result = await ServiceLocator.featureFlagService.setMarketplaceOverride(value);
                              
                              setState(() {
                                _isLoading = false;
                                _statusMessage = result
                                    ? 'Local override set successfully!'
                                    : 'Failed to set local override.';
                                _marketplaceEnabled = value;
                                _hasLocalOverride = true;
                                _localOverrideValue = value;
                              });
                            } catch (e) {
                              setState(() {
                                _isLoading = false;
                                _statusMessage = 'Error setting local override: $e';
                              });
                            }
                          },
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          _marketplaceEnabled ? 'Enabled' : 'Disabled',
                          style: TextStyle(
                            fontSize: 14,
                            color: _marketplaceEnabled
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                        if (_hasLocalOverride) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.yellowPrimary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.yellowPrimary,
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'Local Override',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.yellowPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_hasLocalOverride) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Clear Override'),
                        onPressed: _isLoading ? null : () async {
                          setState(() {
                            _isLoading = true;
                            _statusMessage = 'Clearing local override...';
                          });
                          
                          try {
                            final result = await ServiceLocator.featureFlagService.clearMarketplaceOverride();
                            
                            // Get the remote config value
                            final remoteConfig = FirebaseRemoteConfig.instance;
                            final remoteValue = remoteConfig.getBool(FeatureFlags.enableMarketplace);
                            
                            setState(() {
                              _isLoading = false;
                              _statusMessage = result
                                  ? 'Local override cleared successfully!'
                                  : 'Failed to clear local override.';
                              _marketplaceEnabled = remoteValue;
                              _hasLocalOverride = false;
                              _localOverrideValue = null;
                            });
                          } catch (e) {
                            setState(() {
                              _isLoading = false;
                              _statusMessage = 'Error clearing local override: $e';
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.yellowPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoading ? null : _forceRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Force Refresh Remote Config'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 16,
                    color: _statusMessage.contains('successfully')
                        ? AppColors.success
                        : _statusMessage.contains('Failed') || _statusMessage.contains('Error')
                            ? AppColors.error
                            : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Debug Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remote Config Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Marketplace Feature: ${_marketplaceEnabled ? 'Enabled' : 'Disabled'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Default Value: $_defaultValue',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Remote Value: $_remoteValue',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_hasLocalOverride) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Local Override: ${_localOverrideValue! ? 'Enabled' : 'Disabled'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.yellowPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      'Note: If the feature flag is not updating, check the Firebase Console to ensure the parameter is set correctly.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Firebase Services',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Firebase Analytics: ',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Initialized',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Firebase Analytics is required for Remote Config A/B testing functionality.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Notifications Tab
  Widget _buildNotificationsTab() {
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(
                color: _isInitialized ? AppColors.textGray : AppColors.error,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.textGray),
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
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.textGray),
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
