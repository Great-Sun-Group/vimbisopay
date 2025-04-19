import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/screens/debug/api_config_tab.dart';
import 'package:vimbisopay_app/presentation/screens/debug/app_updates_tab.dart';
import 'package:vimbisopay_app/presentation/screens/debug/feature_flags_tab.dart';
import 'package:vimbisopay_app/presentation/screens/debug/notifications_tab.dart';

/// Debug screen for the VimbisoPay app.
///
/// This screen provides debugging tools for the app, such as:
/// - Managing API environment (Development/Production)
/// - Forcing a refresh of the Remote Config
/// - Viewing the current values of feature flags
/// - Testing app updates
/// - Debugging push notifications
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> with SingleTickerProviderStateMixin {
  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            Tab(text: 'API Config'),
            Tab(text: 'Feature Flags'),
            Tab(text: 'App Updates'),
            Tab(text: 'Notifications'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // API Config Tab
          ApiConfigTab(),
          
          // Feature Flags Tab
          FeatureFlagsTab(),
          
          // App Updates Tab
          AppUpdatesTab(),
          
          // Notifications Tab
          NotificationsTab(),
        ],
      ),
    );
  }
}
