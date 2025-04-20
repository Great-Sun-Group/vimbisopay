import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/debug/debug_card.dart';
import 'package:vimbisopay_app/presentation/widgets/debug/debug_section.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Tab for managing app updates in the debug screen.
class AppUpdatesTab extends StatefulWidget {
  const AppUpdatesTab({super.key});

  @override
  State<AppUpdatesTab> createState() => _AppUpdatesTabState();
}

class _AppUpdatesTabState extends State<AppUpdatesTab> {
  bool _checkingForUpdates = false;
  String _updateStatus = '';
  Map<String, dynamic>? _updateInfo;
  String _currentAppVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  // Load app version
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentAppVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      Logger.error('Error loading app version', e);
      if (mounted) {
        setState(() {
          _currentAppVersion = 'Unknown';
        });
      }
    }
  }

  // Method to check for updates
  Future<void> _checkForUpdates() async {
    setState(() {
      _checkingForUpdates = true;
      _updateStatus = 'Checking for updates...';
      _updateInfo = null;
    });
    
    try {
      final updateInfo = await ServiceLocator.configManager.checkForUpdate();
      
      setState(() {
        _checkingForUpdates = false;
        if (updateInfo != null) {
          _updateInfo = updateInfo;
          _updateStatus = 'Update available: ${updateInfo['latest_version']}';
          
          // Log additional information
          Logger.data('Update priority: ${updateInfo['update_priority']}');
          Logger.data('Update type: ${updateInfo['update_type']}');
          Logger.data('Update required: ${updateInfo['update_required']}');
        } else {
          _updateStatus = 'No updates available';
        }
      });
    } catch (e) {
      setState(() {
        _checkingForUpdates = false;
        _updateStatus = 'Error checking for updates: $e';
      });
      Logger.error('Error checking for updates', e);
    }
  }

  // Helper method to format file size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DebugCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current App Version',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentAppVersion,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            DebugSection(
              title: 'App Update Testing',
              children: [
                FilledButton.icon(
                  onPressed: _checkingForUpdates ? null : _checkForUpdates,
                  icon: const Icon(Icons.system_update),
                  label: const Text('Check for Updates'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_checkingForUpdates)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                if (_updateStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      _updateStatus,
                      style: TextStyle(
                        fontSize: 16,
                        color: _updateStatus.contains('available')
                            ? AppColors.success
                            : _updateStatus.contains('No updates') || _updateStatus.contains('Error')
                                ? AppColors.error
                                : AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_updateInfo != null) ...[
                  const SizedBox(height: 16),
                  DebugCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DebugInfoRow(
                          label: 'Version',
                          value: _updateInfo!['latest_version'] ?? 'Unknown',
                        ),
                        DebugInfoRow(
                          label: 'Required',
                          value: _updateInfo!['update_required'] ? 'Yes' : 'No',
                        ),
                        DebugInfoRow(
                          label: 'Priority',
                          value: _updateInfo!['update_priority']?.toString() ?? 'Unknown',
                        ),
                        DebugInfoRow(
                          label: 'Type',
                          value: _updateInfo!['update_type']?.toString() ?? 'Unknown',
                        ),
                        if (_updateInfo!['file_size_bytes'] != null)
                          DebugInfoRow(
                            label: 'Size',
                            value: _formatFileSize(_updateInfo!['file_size_bytes']),
                          ),
                        const SizedBox(height: 16),
                        const Text(
                          'Release Notes:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _updateInfo!['release_notes'] ?? 'No release notes available',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  final result = await ServiceLocator.configManager.showUpdateDialog(
                                    context,
                                    _updateInfo!,
                                  );
                                  
                                  if (result && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('User chose to update')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.visibility),
                                label: const Text('Show Dialog'),
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
                                  setState(() {
                                    _checkingForUpdates = true;
                                    _updateStatus = 'Downloading update...';
                                  });
                                  
                                  try {
                                    final result = await ServiceLocator.configManager.downloadAndInstallUpdate(
                                      _updateInfo!['update_url'],
                                    );
                                    
                                    setState(() {
                                      _checkingForUpdates = false;
                                      _updateStatus = result
                                          ? 'Update downloaded successfully!'
                                          : 'Failed to download update.';
                                    });
                                  } catch (e) {
                                    setState(() {
                                      _checkingForUpdates = false;
                                      _updateStatus = 'Error downloading update: $e';
                                    });
                                  }
                                },
                                icon: const Icon(Icons.download),
                                label: const Text('Download'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: AppColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
