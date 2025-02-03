import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/presentation/screens/debug_screen.dart';
import 'package:vimbisopay_app/presentation/screens/profile_settings_screen.dart';
import 'package:vimbisopay_app/presentation/screens/security_settings_screen.dart';
import 'package:vimbisopay_app/presentation/screens/notifications_settings_screen.dart';
import 'package:vimbisopay_app/application/usecases/upgrade_member_tier.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_container.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Account & Profile Card
            SettingsContainer(
              title: 'Account & Profile',
              children: [
                _buildSettingsTile(
                  icon: Icons.person_outline,
                  title: 'Profile & Member Status',
                  subtitle: 'Personal info, handle, and tier benefits',
                  onTap: () async {
                    Logger.interaction('User tapped Profile Settings');
                    try {
                      final accountRepository = AccountRepositoryImpl();
                      final userResult = await accountRepository.getCurrentUser();

                      if (!context.mounted) return;

                      await userResult.fold(
                        (failure) {
                          Logger.error('Failed to get current user', failure);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Unable to load profile. Please try again.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        },
                        (user) async {
                          if (user == null) {
                            Logger.error('User session not found');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('User session expired. Please log in again.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MultiProvider(
                                providers: [
                                  Provider<User>.value(value: user),
                                  Provider(
                                    create: (context) => UpgradeMemberTier(accountRepository),
                                  ),
                                ],
                                child: const ProfileSettingsScreen(),
                              ),
                            ),
                          );
                        },
                      );
                    } catch (e, stackTrace) {
                      Logger.error('Failed to navigate to Profile Settings', e, stackTrace);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('An unexpected error occurred. Please try again.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
            const SizedBox(height: 16),
            // Security & Privacy Card
            SettingsContainer(
              title: 'Security & Privacy',
              children: [
                _buildSettingsTile(
                  icon: Icons.security,
                  title: 'Security Settings',
                  subtitle: 'PIN, password, and authentication',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SecuritySettingsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
            const SizedBox(height: 16),
            // Notifications Card
            SettingsContainer(
              title: 'Notifications',
              children: [
                _buildSettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notification Preferences',
                  subtitle: 'Customize alerts and push notifications',
                  onTap: () {
                    Navigator.pushNamed(context, '/notifications-settings');
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
            const SizedBox(height: 16),
            // Support & App Card
            SettingsContainer(
              title: 'Support & App',
              children: [
                _buildSettingsTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  subtitle: 'Get assistance and contact support',
                  onTap: () {
                    // TODO: Implement help & support
                  },
                ),
                const SizedBox(height: 12),
                if (kDebugMode) ...[
                  _buildSettingsTile(
                    icon: Icons.bug_report,
                    title: 'Debug Mode',
                    subtitle: 'Developer options and testing',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DebugScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _buildSettingsTile(
                  icon: Icons.logout,
                  title: 'Logout',
                  subtitle: 'Sign out of your account',
                  showDivider: false,
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text(
                          'Logout',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: const Text(
                          'Are you sure you want to logout?',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Logout',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      Logger.interaction('User confirmed logout');
                      
                      // Show loading dialog
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => WillPopScope(
                            onWillPop: () async => false,
                            child: const AlertDialog(
                              backgroundColor: AppColors.surface,
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Logging out...',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      try {
                        final securityService = SecurityService();
                        await securityService.clearAllData();
                        Logger.state('All user data cleared for logout');
                        
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        Logger.error('Error during logout', e);
                        if (context.mounted) {
                          Navigator.pop(context); // Dismiss loading dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to logout. Please try again.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    bool showDivider = true,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.highlightOverlay,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          overlayColor: WidgetStateProperty.all(AppColors.highlightOverlay),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
