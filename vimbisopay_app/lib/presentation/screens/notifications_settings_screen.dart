import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/theme/app_spacing.dart';
import 'package:vimbisopay_app/core/theme/app_text_styles.dart';
import 'package:vimbisopay_app/domain/entities/notification_preferences.dart';
import 'package:vimbisopay_app/presentation/blocs/notifications/notifications_bloc.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_container.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_switch_tile.dart';

class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationsBloc(
        context.read<SharedPreferences>(),
      )..add(NotificationsInitialize()),
      child: const NotificationsSettingsView(),
    );
  }
}

class NotificationsSettingsView extends StatelessWidget {
  const NotificationsSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
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
      body: BlocConsumer<NotificationsBloc, NotificationsState>(
        listenWhen: (previous, current) => current is NotificationsError,
        listener: (context, state) {
          if (state is NotificationsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        buildWhen: (previous, current) => 
          current is NotificationsLoading || current is NotificationsLoaded,
        builder: (context, state) {
          if (state is NotificationsLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            );
          }

          if (state is NotificationsLoaded) {
            return NotificationsContent(preferences: state.preferences);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class NotificationsContent extends StatefulWidget {
  final NotificationPreferences preferences;

  const NotificationsContent({
    super.key,
    required this.preferences,
  });

  @override
  State<NotificationsContent> createState() => _NotificationsContentState();
}

class _NotificationsContentState extends State<NotificationsContent> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          const GeneralSection(),
          AnimatedSwitcher(
            duration: Duration(milliseconds: AppSpacing.mediumAnimationDuration),
            child: widget.preferences.masterEnabled
                ? Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg),
                    child: Column(
                      children: const [
                        MoneyTransfersSection(),
                        SizedBox(height: 16),
                        AccountSection(),
                        SizedBox(height: 16),
                        UpdatesSection(),
                        SizedBox(height: 16),
                        PrivacySection(),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class GeneralSection extends StatelessWidget {
  const GeneralSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      buildWhen: (previous, current) {
        if (previous is NotificationsLoaded && current is NotificationsLoaded) {
          return previous.preferences.masterEnabled != current.preferences.masterEnabled;
        }
        return current is NotificationsLoaded;
      },
      builder: (context, state) {
        if (state is! NotificationsLoaded) {
          return const SizedBox.shrink();
        }

        return SettingsContainer(
          title: 'General',
          children: [
            SettingsSwitchTile(
              title: 'Push Notifications',
              subtitle: 'Enable or disable all push notifications',
              icon: Icons.notifications,
              value: state.preferences.masterEnabled,
              onChanged: (value) => context.read<NotificationsBloc>().add(
                    UpdateNotificationPreference(
                      state.preferences.copyWith(masterEnabled: value),
                    ),
                  ),
              showDivider: false,
            ),
          ],
        );
      },
    );
  }
}

class MoneyTransfersSection extends StatelessWidget {
  const MoneyTransfersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      buildWhen: (previous, current) {
        if (previous is NotificationsLoaded && current is NotificationsLoaded) {
          final prev = previous.preferences;
          final curr = current.preferences;
          return prev.moneyTransfersSent != curr.moneyTransfersSent ||
              prev.moneyTransfersReceived != curr.moneyTransfersReceived ||
              prev.transferFailures != curr.transferFailures;
        }
        return current is NotificationsLoaded;
      },
      builder: (context, state) {
        if (state is! NotificationsLoaded) {
          return const SizedBox.shrink();
        }

        final prefs = state.preferences;
        return SettingsContainer(
          title: 'Money Transfers',
          children: [
            SettingsSwitchTile(
              title: 'Sent Transfers',
              subtitle: 'Get notified when you send money',
              icon: Icons.send,
              value: prefs.moneyTransfersSent,
              onChanged: (value) => context.read<NotificationsBloc>().add(
                    UpdateNotificationPreference(
                      prefs.copyWith(moneyTransfersSent: value),
                    ),
                  ),
            ),
            SettingsSwitchTile(
              title: 'Received Transfers',
              subtitle: 'Get notified when you receive money',
              icon: Icons.download,
              value: prefs.moneyTransfersReceived,
              onChanged: (value) => context.read<NotificationsBloc>().add(
                    UpdateNotificationPreference(
                      prefs.copyWith(moneyTransfersReceived: value),
                    ),
                  ),
            ),
            SettingsSwitchTile(
              title: 'Failed Transfers',
              subtitle: 'Get notified about failed transactions',
              icon: Icons.error_outline,
              value: prefs.transferFailures,
              onChanged: (value) => context.read<NotificationsBloc>().add(
                    UpdateNotificationPreference(
                      prefs.copyWith(transferFailures: value),
                    ),
                  ),
              showDivider: false,
            ),
          ],
        );
      },
    );
  }
}

class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      buildWhen: (previous, current) {
        if (previous is NotificationsLoaded && current is NotificationsLoaded) {
          final prev = previous.preferences;
          final curr = current.preferences;
          return prev.balanceUpdates != curr.balanceUpdates ||
              prev.accountLimits != curr.accountLimits ||
              prev.securityAlerts != curr.securityAlerts;
        }
        return current is NotificationsLoaded;
      },
      builder: (context, state) {
        if (state is! NotificationsLoaded) {
          return const SizedBox.shrink();
        }

        final prefs = state.preferences;
        return SettingsContainer(
          title: 'Account',
          children: [
            SettingsSwitchTile(
              title: 'Balance Updates',
              subtitle: 'Get notified about balance changes',
              icon: Icons.account_balance_wallet,
              value: prefs.balanceUpdates,
              onChanged: (value) => context.read<NotificationsBloc>().add(
                    UpdateNotificationPreference(
                      prefs.copyWith(balanceUpdates: value),
                    ),
                  ),
            ),
            SettingsSwitchTile(
              title: 'Account Limits',
              subtitle: 'Get notified about limit changes',
              icon: Icons.speed,
              value: prefs.accountLimits,
              onChanged: (value) => context.read<NotificationsBloc>().add(
                    UpdateNotificationPreference(
                      prefs.copyWith(accountLimits: value),
                    ),
                  ),
            ),
            SettingsSwitchTile(
              title: 'Security Alerts',
              subtitle: 'Get notified about security events',
              icon: Icons.security,
              value: prefs.securityAlerts,
              onChanged: (value) => context.read<NotificationsBloc>().add(
                    UpdateNotificationPreference(
                      prefs.copyWith(securityAlerts: value),
                    ),
                  ),
              showDivider: false,
            ),
          ],
        );
      },
    );
  }
}

class UpdatesSection extends StatelessWidget {
  const UpdatesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      buildWhen: (previous, current) {
        if (previous is NotificationsLoaded && current is NotificationsLoaded) {
          final prev = previous.preferences;
          final curr = current.preferences;
          return prev.serviceUpdates != curr.serviceUpdates ||
              prev.appUpdates != curr.appUpdates ||
              prev.newFeatures != curr.newFeatures;
        }
        return current is NotificationsLoaded;
      },
      builder: (context, state) {
        if (state is! NotificationsLoaded) {
          return const SizedBox.shrink();
        }

        final prefs = state.preferences;
        return SettingsContainer(
          title: 'Updates & News',
          children: [
            SettingsSwitchTile(
              title: 'Service Updates',
              subtitle: 'Get notified about service changes',
              icon: Icons.update,
              value: prefs.serviceUpdates,
              onChanged: (value) => context.read<NotificationsBloc>().add(
                    UpdateNotificationPreference(
                      prefs.copyWith(serviceUpdates: value),
                    ),
                  ),
            ),
            SettingsSwitchTile(
              title: 'App Updates',
              subtitle: 'Get notified about app updates',
              icon: Icons.system_update,
              value: prefs.appUpdates,
              onChanged: (value) => context.read<NotificationsBloc>().add(
                    UpdateNotificationPreference(
                      prefs.copyWith(appUpdates: value),
                    ),
                  ),
            ),
            SettingsSwitchTile(
              title: 'New Features',
              subtitle: 'Get notified about new features',
              icon: Icons.new_releases,
              value: prefs.newFeatures,
              onChanged: (value) => context.read<NotificationsBloc>().add(
                    UpdateNotificationPreference(
                      prefs.copyWith(newFeatures: value),
                    ),
                  ),
              showDivider: false,
            ),
          ],
        );
      },
    );
  }
}

class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      buildWhen: (previous, current) {
        if (previous is NotificationsLoaded && current is NotificationsLoaded) {
          return previous.preferences.hidePreviewContent != 
                 current.preferences.hidePreviewContent;
        }
        return current is NotificationsLoaded;
      },
      builder: (context, state) {
        if (state is! NotificationsLoaded) {
          return const SizedBox.shrink();
        }

        final prefs = state.preferences;
        return SettingsContainer(
          title: 'Privacy',
          children: [
            SettingsSwitchTile(
              title: 'Hide Sensitive Content',
              subtitle: 'Hide amounts in notification previews',
              icon: Icons.visibility_off,
              value: prefs.hidePreviewContent,
              onChanged: (value) => context.read<NotificationsBloc>().add(
                    UpdateNotificationPreference(
                      prefs.copyWith(hidePreviewContent: value),
                    ),
                  ),
              showDivider: false,
            ),
          ],
        );
      },
    );
  }
}
