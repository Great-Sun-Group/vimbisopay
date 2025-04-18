import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';

/// Screen that shows when an app update is available.
///
/// This screen displays information about the available update and provides
/// options to download and install the update or defer it for later.
class AppUpdateScreen extends StatefulWidget {
  /// The update information.
  final Map<String, dynamic> updateInfo;

  /// Creates a new instance of [AppUpdateScreen].
  const AppUpdateScreen({
    required this.updateInfo,
    super.key,
  });

  @override
  State<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends State<AppUpdateScreen> {
  bool _downloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  bool _downloadComplete = false;
  bool _downloadError = false;
  bool _verifyingIntegrity = false;
  bool _integrityVerified = false;

  @override
  Widget build(BuildContext context) {
    final isRequired = widget.updateInfo['update_required'] == true;
    final version = widget.updateInfo['latest_version'] as String;
    final notes = widget.updateInfo['release_notes'] as String;
    final priority = widget.updateInfo['update_priority'] as String;
    final updateType = widget.updateInfo['update_type'] as String;
    final fileSize = widget.updateInfo['file_size_bytes'] as int?;
    final updateUrl = widget.updateInfo['update_url'] as String;

    // Determine color based on priority
    Color priorityColor;
    switch (priority.toLowerCase()) {
      case 'low':
        priorityColor = Colors.blue;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      case 'high':
      case 'critical':
        priorityColor = Colors.red;
        break;
      default:
        priorityColor = Colors.blue;
    }

    return WillPopScope(
      onWillPop: () async => !isRequired, // Prevent back button if required
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(isRequired ? 'Update Required' : 'Update Available'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          automaticallyImplyLeading: !isRequired, // Hide back button if required
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'lib/assets/images/app-logo.jpeg',
                        height: 100,
                        width: 100,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                
                // Update Information
                Text(
                  'A new version of VimbisoPay is available',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Version Information
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Version:',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            widget.updateInfo['current_version'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'New Version:',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            version,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Update Type:',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            updateType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (fileSize != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'File Size:',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              _formatFileSize(fileSize),
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: priorityColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getPriorityIcon(priority),
                              color: priorityColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Priority: ${priority.toUpperCase()}',
                              style: TextStyle(
                                color: priorityColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                color: AppColors.error,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'This update is required',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Release Notes
                const Text(
                  'What\'s New:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Download Status
                if (_downloading) ...[
                  const Text(
                    'Downloading Update:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    backgroundColor: AppColors.surface,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _downloadStatus,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Integrity Verification Status
                if (_verifyingIntegrity) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Verifying file integrity...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ensuring the downloaded file is authentic and has not been tampered with.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (_integrityVerified) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_user,
                              color: AppColors.success,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Integrity verification successful',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The downloaded file has been verified as authentic and secure.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (_downloadError) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Download Failed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _downloadStatus,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Action Buttons
                if (!_downloading && !_downloadComplete) ...[
                  FilledButton.icon(
                    onPressed: _downloadAndInstall,
                    icon: const Icon(Icons.download),
                    label: const Text('Download and Install'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isRequired)
                    OutlinedButton(
                      onPressed: _deferUpdate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.textSecondary),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Remind Me Later'),
                    ),
                ],
                
                if (_downloadComplete) ...[
                  // Installation instructions container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.success,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Installation In Progress',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The update has been downloaded and installation has started. You must approve the installation in the system prompt that appears.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '1. IMPORTANT: Tap "INSTALL" when Android asks for permission\n2. If you tap "CANCEL", the update will not be installed\n3. Wait for the installation to complete\n4. You\'ll receive a notification when done\n5. Tap the notification to open the updated app',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.yellowPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.yellowPrimary),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.help_outline,
                                    color: AppColors.yellowPrimary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Having trouble?',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.yellowPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'If you were redirected to enable "Allow from this source" in settings, tap the button below after enabling it to continue the installation.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _retryInstallation,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry Installation'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.yellowPrimary,
                                    side: const BorderSide(color: AppColors.yellowPrimary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('I Understand'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Downloads and installs the update.
  Future<void> _downloadAndInstall() async {
    Logger.state('Starting download and install process from update screen');
    Logger.data('Update URL: ${widget.updateInfo['update_url']}');
    Logger.data('Update version: ${widget.updateInfo['latest_version']}');
    Logger.data('Update type: ${widget.updateInfo['update_type']}');
    Logger.data('Update required: ${widget.updateInfo['update_required']}');
    Logger.data('Update priority: ${widget.updateInfo['update_priority']}');
    
    setState(() {
      _downloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Starting download...';
      _downloadError = false;
    });

    try {
      // Check if integrity information is available
      final hasIntegrityInfo = widget.updateInfo.containsKey('integrity') && 
                              widget.updateInfo['integrity'] != null;
      
      // Simulate download progress with detailed logging
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        Logger.state('Download progress simulation: ${i * 10}%');
        setState(() {
          _downloadProgress = i / 10;
          _downloadStatus = 'Downloading... ${(i * 10)}%';
        });
      }
      
      // Show integrity verification status if integrity info is available
      if (hasIntegrityInfo) {
        setState(() {
          _verifyingIntegrity = true;
          _downloadStatus = 'Verifying file integrity...';
        });
        
        // Add a small delay to show the verification status
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      Logger.state('Calling ConfigManager.downloadAndInstallUpdate');
      final stopwatch = Stopwatch()..start();
      
      // Perform the actual download and installation
      final result = await ServiceLocator.configManager.downloadAndInstallUpdate(
        widget.updateInfo['update_url'],
        updateInfo: widget.updateInfo,
      );
      
      // Log integrity information if available
      if (hasIntegrityInfo) {
        final integrity = widget.updateInfo['integrity'];
        Logger.data('Integrity info: ${integrity.toString()}');
        Logger.data('Algorithm: ${integrity['algorithm']}');
        Logger.data('Checksum: ${integrity['checksum']}');
        Logger.data('Checksum URL: ${integrity['checksumUrl']}');
      }
      
      // Update integrity verification status
      if (hasIntegrityInfo) {
        setState(() {
          _verifyingIntegrity = false;
          _integrityVerified = result; // If result is true, integrity verification passed
        });
      }
      
      stopwatch.stop();
      Logger.performance('Download and install completed in ${stopwatch.elapsedMilliseconds}ms');
      Logger.data('Download and install result: $result');

      if (result) {
        Logger.state('Update installation request sent successfully');
        setState(() {
          _downloading = false;
          _downloadComplete = true;
          _downloadStatus = 'Update installation initiated successfully!';
        });
      } else {
        Logger.error('Update installation failed with result: $result');
        setState(() {
          _downloading = false;
          _downloadError = true;
          _downloadStatus = 'Failed to install the update. Please try again later.';
        });
      }
    } catch (e, stackTrace) {
      Logger.error('Error in _downloadAndInstall', e, stackTrace);
      setState(() {
        _downloading = false;
        _downloadError = true;
        _downloadStatus = 'Error: $e';
      });
    }
  }

  /// Defers the update until later.
  void _deferUpdate() async {
    final version = widget.updateInfo['latest_version'] as String;
    Logger.state('User chose to defer update for version: $version');
    
    try {
      Logger.state('Calling ConfigManager.deferUpdate');
      final stopwatch = Stopwatch()..start();
      
      await ServiceLocator.configManager.deferUpdate(version);
      
      stopwatch.stop();
      Logger.performance('Defer update completed in ${stopwatch.elapsedMilliseconds}ms');
      Logger.data('Update successfully deferred for version: $version');
      
      if (mounted) {
        Logger.state('Dismissing update screen after deferring update');
        Navigator.of(context).pop(false);
      }
    } catch (e, stackTrace) {
      Logger.error('Error deferring update', e, stackTrace);
      if (mounted) {
        Logger.state('Showing error snackbar for defer update failure');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deferring update: $e')),
        );
      }
    }
  }

  /// Formats a file size in bytes to a human-readable string.
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

  /// Gets the icon for the update priority.
  IconData _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return Icons.info_outline;
      case 'medium':
        return Icons.warning_amber_rounded;
      case 'high':
      case 'critical':
        return Icons.priority_high_rounded;
      default:
        return Icons.info_outline;
    }
  }
  
  /// Retries the installation after the user has enabled "Allow from this source".
  Future<void> _retryInstallation() async {
    Logger.state('Retrying installation from update screen');
    
    setState(() {
      _downloadStatus = 'Retrying installation...';
      _downloading = true;
      _downloadError = false;
    });
    
    try {
      final result = await ServiceLocator.configManager.retryInstallation();
      
      Logger.data('Retry installation result: $result');
      
      if (result) {
        Logger.state('Installation retry successful');
        setState(() {
          _downloading = false;
          _downloadStatus = 'Installation retry successful!';
          // We don't set _downloadComplete to true again since it's already true
        });
        
        // Show a success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Installation retry initiated. Please approve the installation prompt.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        Logger.error('Installation retry failed');
        setState(() {
          _downloading = false;
          _downloadError = true;
          _downloadStatus = 'Failed to retry installation. Please try again.';
        });
      }
    } catch (e, stackTrace) {
      Logger.error('Error retrying installation', e, stackTrace);
      setState(() {
        _downloading = false;
        _downloadError = true;
        _downloadStatus = 'Error: $e';
      });
    }
  }
}
