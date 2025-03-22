import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';

/// Service for managing app updates in the VimbisoPay app.
///
/// This service checks for app updates from the server and handles the update process.
/// It supports both optional and mandatory updates, and can download and install APK files.
class AppUpdateService {
  final http.Client _httpClient;
  final SharedPreferences _prefs;
  final String _baseUrl;
  
  // Keys for SharedPreferences
  static const String _lastCheckTimeKey = 'last_update_check_time';
  static const String _updateDeferredKey = 'update_deferred';
  static const String _deferredVersionKey = 'deferred_version';
  
  /// Creates a new instance of [AppUpdateService].
  ///
  /// Requires an instance of [http.Client] and [SharedPreferences].
  AppUpdateService(this._httpClient, this._prefs, this._baseUrl);
  
  /// Checks if an update is available for the app.
  ///
  /// Returns a [Map] containing information about the available update,
  /// or null if no update is available.
  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final packageName = packageInfo.packageName;
      
      // Get device info
      final deviceInfo = await _getDeviceInfo();
      
      // Get user info from database
      final user = await ServiceLocator.databaseHelper.getUser();
      final userId = user?.memberId;
      
      // Build request body
      final requestBody = {
        'app_id': packageName,
        'current_version': currentVersion,
        'device_info': deviceInfo,
        if (userId != null) 'user_info': {'user_id': userId},
      };
      
      // Make API request
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/api/v1/app/version-check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Update last check time
        await _prefs.setInt(_lastCheckTimeKey, DateTime.now().millisecondsSinceEpoch);
        
        // Check if update is available
        if (data['update_available'] == true) {
          // Check if this update was previously deferred
          final deferredVersion = _prefs.getString(_deferredVersionKey);
          final updateDeferred = _prefs.getBool(_updateDeferredKey) ?? false;
          
          // If this is a required update or not the deferred version, return update info
          if (data['update_required'] == true || 
              !updateDeferred || 
              deferredVersion != data['latest_version']) {
            return data;
          }
        }
        
        return null;
      } else {
        Logger.error('Error checking for updates: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      Logger.error('Error checking for updates', e);
      return null;
    }
  }
  
  /// Downloads and installs an update from the given URL.
  ///
  /// Returns true if the download and installation was successful, false otherwise.
  Future<bool> downloadAndInstallUpdate(String url) async {
    try {
      // For Android, download and install the APK
      if (Platform.isAndroid) {
        // Get temporary directory
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/update.apk';
        
        // Download the APK
        final response = await _httpClient.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          // Save the APK to a file
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          
          // Install the APK
          if (await _installApk(filePath)) {
            // Clear deferred status after successful installation
            await _prefs.remove(_updateDeferredKey);
            await _prefs.remove(_deferredVersionKey);
            return true;
          }
        }
      } else {
        // For other platforms, just open the URL
        if (await launchUrl(Uri.parse(url))) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      Logger.error('Error downloading and installing update', e);
      return false;
    }
  }
  
  /// Defers an update until later.
  ///
  /// This will prevent the update from being shown again until the next app launch
  /// or until a new version is available.
  Future<void> deferUpdate(String version) async {
    await _prefs.setBool(_updateDeferredKey, true);
    await _prefs.setString(_deferredVersionKey, version);
  }
  
  /// Clears the deferred status of an update.
  ///
  /// This will allow the update to be shown again.
  Future<void> clearDeferredStatus() async {
    await _prefs.remove(_updateDeferredKey);
    await _prefs.remove(_deferredVersionKey);
  }
  
  /// Shows an update dialog to the user.
  ///
  /// If [required] is true, the user cannot dismiss the dialog and must update.
  /// Returns true if the user chooses to update, false otherwise.
  Future<bool> showUpdateDialog(
    BuildContext context, 
    Map<String, dynamic> updateInfo,
  ) async {
    final isRequired = updateInfo['update_required'] == true;
    final version = updateInfo['latest_version'] as String;
    final notes = updateInfo['release_notes'] as String;
    final priority = updateInfo['update_priority'] as String;
    
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
    
    // Show dialog
    return await showDialog<bool>(
      context: context,
      barrierDismissible: !isRequired,
      builder: (context) => WillPopScope(
        onWillPop: () async => !isRequired,
        child: AlertDialog(
          title: Text(isRequired ? 'Update Required' : 'Update Available'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A new version of VimbisoPay is available (v$version).'),
                const SizedBox(height: 8),
                if (isRequired)
                  const Text(
                    'This update is required to continue using the app.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: priorityColor),
                  ),
                  child: Text(
                    'Priority: ${priority.toUpperCase()}',
                    style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'What\'s New:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(notes),
                if (updateInfo['file_size_bytes'] != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Size: ${_formatFileSize(updateInfo['file_size_bytes'])}',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!isRequired)
              TextButton(
                onPressed: () {
                  deferUpdate(version);
                  Navigator.of(context).pop(false);
                },
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(isRequired ? 'Update Now' : 'Install'),
            ),
          ],
        ),
      ),
    ) ?? false;
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
  
  /// Gets device information for the update check.
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      return {
        'android_version': androidInfo.version.release,
        'device_model': androidInfo.model,
        'screen_size': '${androidInfo.displayMetrics.widthPx.toInt()}x${androidInfo.displayMetrics.heightPx.toInt()}',
      };
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      return {
        'ios_version': iosInfo.systemVersion,
        'device_model': iosInfo.model,
      };
    }
    
    return {};
  }
  
  /// Installs an APK file.
  ///
  /// Returns true if the installation was successful, false otherwise.
  Future<bool> _installApk(String filePath) async {
    try {
      // Use the install_plugin package to install the APK
      // This requires adding the package to pubspec.yaml
      // For now, we'll just open the file with the default app
      final file = File(filePath);
      final uri = Uri.file(file.path);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      Logger.error('Error installing APK', e);
      return false;
    }
  }
}
