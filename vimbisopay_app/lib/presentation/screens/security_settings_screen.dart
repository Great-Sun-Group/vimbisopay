import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/theme/app_spacing.dart';
import 'package:vimbisopay_app/core/theme/app_text_styles.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/domain/entities/security_event.dart';
import 'package:vimbisopay_app/presentation/widgets/change_password_bottom_sheet.dart';
import 'package:vimbisopay_app/presentation/widgets/change_pin_bottom_sheet.dart';
import 'package:vimbisopay_app/presentation/widgets/security_events_list.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_container.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_switch_tile.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _securityService = ServiceLocator.securityService;
  bool _isLoading = true;
  String? _error;
  bool _useBiometric = false;
  bool _isBiometricAvailable = false;
  bool _isLoadingEvents = true;
  List<SecurityEvent> _securityEvents = [];

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final isBiometricAvailable = await _securityService.isBiometricAvailable();
      final usesBiometric = await _securityService.usesBiometric();
      
      // For demo purposes, create some sample security events
      final events = [
        SecurityEvent(
          type: SecurityEvent.loginSuccess,
          description: 'Successful login',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          deviceInfo: 'iPhone 13 Pro • iOS 15.0',
        ),
        SecurityEvent(
          type: SecurityEvent.passwordChange,
          description: 'Password changed',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          deviceInfo: 'MacBook Pro • macOS 12.0',
        ),
        SecurityEvent(
          type: SecurityEvent.biometricEnabled,
          description: 'Biometric authentication enabled',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          deviceInfo: 'iPhone 13 Pro • iOS 15.0',
        ),
      ];

      if (mounted) {
        setState(() {
          _isBiometricAvailable = isBiometricAvailable;
          _useBiometric = usesBiometric;
          _securityEvents = events;
          _isLoading = false;
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      Logger.error('Error loading security settings', e);
      if (mounted) {
        setState(() {
          _error = 'Failed to load security settings. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    try {
      setState(() => _isLoading = true);

      if (value) {
        await _securityService.setBiometricEnabled();
        if (mounted) {
          setState(() => _useBiometric = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication enabled'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // TODO: Implement disable biometric
      }
    } catch (e) {
      Logger.error('Error toggling biometric', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Security Settings',
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
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSecuritySettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // Authentication Section
                      SettingsContainer(
                        title: 'Authentication',
                        children: [
                          if (_isBiometricAvailable)
                            SettingsSwitchTile(
                              title: 'Biometric Authentication',
                              subtitle: 'Use fingerprint or face recognition',
                              icon: Icons.fingerprint,
                              value: _useBiometric,
                              onChanged: _toggleBiometric,
                            ),
                          SettingsListTile(
                            title: 'Change PIN',
                            subtitle: 'Update your security PIN',
                            icon: Icons.pin,
                            onTap: () async {
                              final result = await showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => const ChangePinBottomSheet(),
                              );
                              
                              if (result == true && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('PIN changed successfully'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                          ),
                          SettingsListTile(
                            title: 'Change Password',
                            subtitle: 'Update your account password',
                            icon: Icons.password,
                            showDivider: false,
                            onTap: () async {
                              final result = await showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => const ChangePasswordBottomSheet(),
                              );
                              
                              if (result == true && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password changed successfully'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SettingsContainer(
                        title: 'Recent Activity',
                        children: [
                          SizedBox(
                            height: 300,
                            child: SecurityEventsList(
                              events: _securityEvents,
                              onRefresh: _loadSecuritySettings,
                              isLoading: _isLoadingEvents,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }
}
