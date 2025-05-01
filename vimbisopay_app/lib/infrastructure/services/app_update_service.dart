import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
    Logger.state('Starting checkForUpdate in AppUpdateService');
    
    try {
      // Get current app version
      Logger.state('Getting current app version');
      final stopwatch = Stopwatch()..start();
      final packageInfo = await PackageInfo.fromPlatform();
      final versionName = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      
      // For API requests, strip the "-debug" suffix if present
      String apiVersionName = versionName;
      bool isDebugBuild = false;
      if (versionName.contains("-debug")) {
        isDebugBuild = true;
        apiVersionName = versionName.replaceAll("-debug", "");
        Logger.data('Debug build detected, using API version: $apiVersionName');
      }
      
      final currentVersion = "$apiVersionName+$buildNumber";
      final packageName = packageInfo.packageName;
      stopwatch.stop();
      
      Logger.data('Current version name: $versionName');
      Logger.data('Current build number: $buildNumber');
      Logger.data('Full app version: $currentVersion');
      Logger.data('Is debug build: $isDebugBuild');
      Logger.data('Package name: $packageName');
      Logger.performance('PackageInfo retrieved in ${stopwatch.elapsedMilliseconds}ms');
      
      // Get device info
      Logger.state('Getting device info');
      final deviceInfoStopwatch = Stopwatch()..start();
      final deviceInfo = await _getDeviceInfo();
      deviceInfoStopwatch.stop();
      
      Logger.data('Device info: $deviceInfo');
      Logger.performance('Device info retrieved in ${deviceInfoStopwatch.elapsedMilliseconds}ms');
      
      // Get user info from database
      Logger.state('Getting user info from database');
      final userStopwatch = Stopwatch()..start();
      final user = await ServiceLocator.databaseHelper.getUser();
      final userId = user?.memberId;
      userStopwatch.stop();
      
      Logger.data('User ID: ${userId ?? 'not found'}');
      Logger.performance('User info retrieved in ${userStopwatch.elapsedMilliseconds}ms');
      
      // Build request body
      final requestBody = {
        'app_id': packageName,
        'current_version': currentVersion,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'device_info': deviceInfo,
        if (userId != null) 'user_info': {'user_id': userId},
      };
      
      Logger.data('Version check request body: ${jsonEncode(requestBody)}');
      
      // Make API request
      Logger.state('Making API request to check for updates');
      final apiStopwatch = Stopwatch()..start();
      
      final uri = Uri.parse('$_baseUrl/app/version-check');
      Logger.data('Version check URL: $uri');
      
      final response = await _httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-client-api-key': ApiConfig.apiKey,
        },
        body: jsonEncode(requestBody),
      );
      
      apiStopwatch.stop();
      Logger.performance('API request completed in ${apiStopwatch.elapsedMilliseconds}ms');
      Logger.data('Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        Logger.state('API request successful, parsing response');
        final parseStopwatch = Stopwatch()..start();
        final responseData = jsonDecode(response.body);
        parseStopwatch.stop();
        
        Logger.performance('Response parsed in ${parseStopwatch.elapsedMilliseconds}ms');
        Logger.data('Response data: ${jsonEncode(responseData)}');
        
        // Update last check time
        await _prefs.setInt(_lastCheckTimeKey, DateTime.now().millisecondsSinceEpoch);
        Logger.data('Updated last check time: ${DateTime.now().toIso8601String()}');
        
        // Handle new response structure
        if (responseData.containsKey('data') && 
            responseData['data'].containsKey('action') &&
            responseData['data']['action'].containsKey('details')) {
          
          final details = responseData['data']['action']['details'];
          Logger.data('Update details: ${jsonEncode(details)}');
          
          // Check if update is available
          if (details['update_available'] == true) {
            Logger.state('Update available: ${details['latest_version']}');
            
            // Check if this update was previously deferred
            final deferredVersion = _prefs.getString(_deferredVersionKey);
            final updateDeferred = _prefs.getBool(_updateDeferredKey) ?? false;
            
            Logger.data('Deferred version: $deferredVersion');
            Logger.data('Update deferred: $updateDeferred');
            
            // If this is a required update or not the deferred version, return update info
            if (details['update_required'] == true || 
                !updateDeferred || 
                deferredVersion != details['latest_version']) {
              
              if (details['update_required'] == true) {
                Logger.state('Required update detected, must be installed');
              } else if (!updateDeferred) {
                Logger.state('Update not previously deferred');
              } else if (deferredVersion != details['latest_version']) {
                Logger.state('New version different from deferred version');
              }
              
              return details;
            } else {
              Logger.state('Update was previously deferred, not showing again');
              return null;
            }
          } else {
            Logger.state('No update available');
            return null;
          }
        } else {
          Logger.error('Unexpected response structure: ${jsonEncode(responseData)}');
          return null;
        }
      } else {
        Logger.error('Error checking for updates: ${response.statusCode}');
        Logger.data('Response body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      Logger.error('Error checking for updates', e, stackTrace);
      return null;
    }
  }
  
  /// Downloads and installs an update from the given URL.
  ///
  /// If integrity information is provided, the downloaded file will be verified
  /// before installation.
  ///
  /// Returns true if the download and installation was successful, false otherwise.
  Future<bool> downloadAndInstallUpdate(String url, {Map<String, dynamic>? integrity}) async {
    Logger.state('Starting downloadAndInstallUpdate in AppUpdateService');
    Logger.data('Download URL: $url');
    if (integrity != null) {
      Logger.data('Integrity info provided: ${jsonEncode(integrity)}');
    }
    
    try {
      // For Android, download and install the APK
      if (Platform.isAndroid) {
        Logger.data('Platform: Android - proceeding with APK download');
        
        // Get temporary directory
        Logger.state('Getting temporary directory');
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/update.apk';
        Logger.data('APK will be saved to: $filePath');
        
        // Download the APK
        Logger.state('Initiating HTTP GET request to download APK');
        final stopwatch = Stopwatch()..start();
        final response = await _httpClient.get(Uri.parse(url));
        stopwatch.stop();
        
        Logger.data('HTTP response received in ${stopwatch.elapsedMilliseconds}ms');
        Logger.data('Response status code: ${response.statusCode}');
        Logger.data('Response content length: ${response.contentLength ?? 'unknown'} bytes');
        
        if (response.statusCode == 200) {
          Logger.state('HTTP request successful, writing APK to file');
          
          // Save the APK to a file
          final file = File(filePath);
          Logger.data('Creating file at: $filePath');
          
          final writeStopwatch = Stopwatch()..start();
          await file.writeAsBytes(response.bodyBytes);
          writeStopwatch.stop();
          
          Logger.data('File written in ${writeStopwatch.elapsedMilliseconds}ms');
          Logger.data('File size: ${file.lengthSync()} bytes');
          
          // Verify file integrity if integrity information is provided
          if (integrity != null) {
            Logger.state('Verifying file integrity');
            final verificationResult = await _verifyFileIntegrity(
              filePath, 
              integrity['algorithm'] ?? 'sha256',
              integrity['checksum'],
              checksumUrl: integrity['checksumUrl']
            );
            
            if (!verificationResult) {
              Logger.error('File integrity verification failed');
              return false;
            }
            
            Logger.state('File integrity verification successful');
          }
          
          // Initiate APK installation
          Logger.state('Initiating APK installation from: $filePath');
          if (await _installApk(filePath)) {
            Logger.state('APK installation request sent to Android package installer');
            
            // Clear deferred status after successful installation
            Logger.state('Clearing deferred update status');
            await _prefs.remove(_updateDeferredKey);
            await _prefs.remove(_deferredVersionKey);
            
            return true;
          } else {
            Logger.error('APK installation failed');
            return false;
          }
        } else {
          Logger.error('HTTP request failed with status: ${response.statusCode}');
          Logger.data('Response body: ${response.body.length > 1000 ? '${response.body.substring(0, 1000)}...' : response.body}');
          return false;
        }
      } else {
        // For other platforms, just open the URL
        Logger.data('Platform: ${Platform.operatingSystem} - opening URL in browser');
        if (await launchUrl(Uri.parse(url))) {
          Logger.state('URL launched successfully');
          return true;
        } else {
          Logger.error('Failed to launch URL: $url');
          return false;
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Error in downloadAndInstallUpdate', e, stackTrace);
      return false;
    }
  }
  
  /// Defers an update until later.
  ///
  /// This will prevent the update from being shown again until the next app launch
  /// or until a new version is available.
  Future<void> deferUpdate(String version) async {
    Logger.state('Deferring update for version: $version');
    
    try {
      await _prefs.setBool(_updateDeferredKey, true);
      await _prefs.setString(_deferredVersionKey, version);
      
      Logger.data('Update deferred successfully');
      Logger.data('Deferred version: $version');
      Logger.data('Deferred key set: ${_prefs.getBool(_updateDeferredKey)}');
      Logger.data('Deferred version key set: ${_prefs.getString(_deferredVersionKey)}');
    } catch (e, stackTrace) {
      Logger.error('Error deferring update', e, stackTrace);
      throw e; // Re-throw to allow UI to handle the error
    }
  }
  
  /// Clears the deferred status of an update.
  ///
  /// This will allow the update to be shown again.
  Future<void> clearDeferredStatus() async {
    Logger.state('Clearing deferred update status');
    
    try {
      final hadDeferredStatus = _prefs.containsKey(_updateDeferredKey);
      final deferredVersion = _prefs.getString(_deferredVersionKey);
      
      await _prefs.remove(_updateDeferredKey);
      await _prefs.remove(_deferredVersionKey);
      
      Logger.data('Deferred status cleared');
      Logger.data('Had deferred status: $hadDeferredStatus');
      Logger.data('Previous deferred version: $deferredVersion');
    } catch (e, stackTrace) {
      Logger.error('Error clearing deferred status', e, stackTrace);
      throw e; // Re-throw to allow UI to handle the error
    }
  }
  
  /// Shows an update dialog to the user.
  ///
  /// If [required] is true, the user cannot dismiss the dialog and must update.
  /// Returns true if the user chooses to update, false otherwise.
  Future<bool> showUpdateDialog(
    BuildContext context, 
    Map<String, dynamic> updateInfo,
  ) async {
    Logger.state('Showing update dialog');
    Logger.data('Update info: ${jsonEncode(updateInfo)}');
    
    final isRequired = updateInfo['update_required'] == true;
    final version = updateInfo['latest_version'] as String;
    final notes = updateInfo['release_notes'] as String;
    final priority = updateInfo['update_priority'] as String;
    
    Logger.data('Update required: $isRequired');
    Logger.data('Version: $version');
    Logger.data('Priority: $priority');
    Logger.data('Release notes length: ${notes.length} characters');
    
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
    
    Logger.state('Displaying update dialog to user');
    final stopwatch = Stopwatch()..start();
    
    // Show dialog
    final result = await showDialog<bool>(
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
                  Logger.interaction('User chose to defer update');
                  deferUpdate(version);
                  Navigator.of(context).pop(false);
                },
                child: const Text('Later'),
              ),
            FilledButton(
              onPressed: () {
                Logger.interaction('User chose to install update');
                Navigator.of(context).pop(true);
              },
              child: Text(isRequired ? 'Update Now' : 'Install'),
            ),
          ],
        ),
      ),
    ) ?? false;
    
    stopwatch.stop();
    Logger.performance('Update dialog displayed for ${stopwatch.elapsedMilliseconds}ms');
    Logger.data('User decision: ${result ? 'Install update' : 'Defer update'}');
    
    return result;
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
    Logger.state('Getting device information');
    final stopwatch = Stopwatch()..start();
    
    final deviceInfoPlugin = DeviceInfoPlugin();
    Logger.data('Device platform: ${Platform.operatingSystem}');
    
    try {
      if (Platform.isAndroid) {
        Logger.data('Getting Android device info');
        final androidInfo = await deviceInfoPlugin.androidInfo;
        
        // Get device architecture
        String architecture = 'unknown';
        try {
          if (androidInfo.supportedAbis.isNotEmpty) {
            // Get the primary ABI (first in the list)
            final primaryAbi = androidInfo.supportedAbis.first;
            
            // Map ABI to common architecture names
            if (primaryAbi.contains('arm64')) {
              architecture = 'arm64-v8a';
            } else if (primaryAbi.contains('armeabi')) {
              architecture = 'armeabi-v7a';
            } else if (primaryAbi.contains('x86_64')) {
              architecture = 'x86_64';
            } else if (primaryAbi.contains('x86')) {
              architecture = 'x86';
            } else {
              architecture = primaryAbi;
            }
          }
          Logger.data('Device architecture: $architecture');
        } catch (e) {
          Logger.error('Error getting device architecture', e);
        }
        
        final result = {
          'android_version': androidInfo.version.release,
          'device_model': androidInfo.model,
          'screen_size': '${androidInfo.displayMetrics.widthPx.toInt()}x${androidInfo.displayMetrics.heightPx.toInt()}',
          'manufacturer': androidInfo.manufacturer,
          'brand': androidInfo.brand,
          'device': androidInfo.device,
          'sdk_int': androidInfo.version.sdkInt,
          'architecture': architecture,
        };
        
        stopwatch.stop();
        Logger.performance('Android device info retrieved in ${stopwatch.elapsedMilliseconds}ms');
        Logger.data('Android device info: $result');
        
        return result;
      } else if (Platform.isIOS) {
        Logger.data('Getting iOS device info');
        final iosInfo = await deviceInfoPlugin.iosInfo;
        
        final result = {
          'ios_version': iosInfo.systemVersion,
          'device_model': iosInfo.model,
          'name': iosInfo.name,
          'system_name': iosInfo.systemName,
          'identifier_for_vendor': iosInfo.identifierForVendor,
          'is_physical_device': iosInfo.isPhysicalDevice,
        };
        
        stopwatch.stop();
        Logger.performance('iOS device info retrieved in ${stopwatch.elapsedMilliseconds}ms');
        Logger.data('iOS device info: $result');
        
        return result;
      } else {
        Logger.data('Unsupported platform: ${Platform.operatingSystem}');
        stopwatch.stop();
        Logger.performance('Device info retrieval completed in ${stopwatch.elapsedMilliseconds}ms');
        return {'platform': Platform.operatingSystem};
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('Error getting device info', e, stackTrace);
      return {'error': 'Failed to get device info: $e'};
    }
  }
  
  /// Retries the installation of the previously downloaded APK.
  ///
  /// This method should be called after the user has enabled the "Allow from this source" setting.
  /// It will retry the installation of the APK that was previously downloaded.
  ///
  /// Returns true if the retry was successful, false otherwise.
  Future<bool> retryInstallation() async {
    Logger.state('Retrying APK installation');
    
    try {
      if (Platform.isAndroid) {
        // Use the method channel to retry APK installation on Android
        Logger.state('Using Android-specific method channel to retry APK installation');
        final stopwatch = Stopwatch()..start();
        
        try {
          // Create a method channel to communicate with the native code
          const channel = MethodChannel('com.vimbisopay.vimbisopay_app/apk_installer');
          Logger.data('Invoking method channel for retry');
          
          // Call the native method to retry the APK installation
          final result = await channel.invokeMethod<bool>('retryInstallation');
          
          stopwatch.stop();
          Logger.performance('Method channel call completed in ${stopwatch.elapsedMilliseconds}ms');
          Logger.data('Method channel result: $result');
          
          if (result == true) {
            Logger.state('APK installation retry request sent successfully via method channel');
            Logger.state('Note: User must approve installation and restart app to complete update');
            return true;
          } else {
            Logger.error('Failed to send APK installation retry request via method channel');
            return false;
          }
        } on PlatformException catch (e, stackTrace) {
          stopwatch.stop();
          Logger.error('Platform exception in method channel', e, stackTrace);
          Logger.data('Error code: ${e.code}');
          Logger.data('Error message: ${e.message}');
          Logger.data('Error details: ${e.details}');
          return false;
        }
      } else {
        Logger.error('Retry installation is only supported on Android');
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('Error retrying APK installation', e, stackTrace);
      return false;
    }
  }

  /// Initiates the installation of an APK file.
  ///
  /// Returns true if the installation request was successfully sent to the Android package installer,
  /// false otherwise. Note that this does not guarantee the installation was completed or approved by the user.
  /// The user must manually approve the installation and restart the app to use the new version.
  Future<bool> _installApk(String filePath) async {
    Logger.state('Starting _installApk');
    Logger.data('APK file path: $filePath');
    
    try {
      final file = File(filePath);
      
      // Verify file exists and is readable
      if (!file.existsSync()) {
        Logger.error('APK file does not exist at path: $filePath');
        return false;
      }
      
      final fileSize = file.lengthSync();
      Logger.data('APK file size: $fileSize bytes');
      Logger.data('APK file last modified: ${file.lastModifiedSync()}');
      
      if (Platform.isAndroid) {
        // Use the method channel to initiate APK installation on Android
        Logger.state('Using Android-specific method channel to initiate APK installation');
        final stopwatch = Stopwatch()..start();
        
        try {
          // Create a method channel to communicate with the native code
          const channel = MethodChannel('com.vimbisopay.vimbisopay_app/apk_installer');
          Logger.data('Invoking method channel with filePath: $filePath');
          
          // Call the native method to install the APK
          final result = await channel.invokeMethod<bool>('installApk', {'filePath': filePath});
          
          stopwatch.stop();
          Logger.performance('Method channel call completed in ${stopwatch.elapsedMilliseconds}ms');
          Logger.data('Method channel result: $result');
          
          if (result == true) {
            Logger.state('APK installation request sent successfully via method channel');
            Logger.state('Note: User must approve installation and restart app to complete update');
            return true;
          } else {
            Logger.error('Failed to send APK installation request via method channel');
            return false;
          }
        } on PlatformException catch (e, stackTrace) {
          stopwatch.stop();
          Logger.error('Platform exception in method channel', e, stackTrace);
          Logger.data('Error code: ${e.code}');
          Logger.data('Error message: ${e.message}');
          Logger.data('Error details: ${e.details}');
          return false;
        }
      } else {
        // For other platforms, use the existing approach with URL launcher
        Logger.state('Using URL launcher for non-Android platform');
        final uri = Uri.file(file.path);
        Logger.data('File URI: $uri');
        
        final stopwatch = Stopwatch()..start();
        final launchResult = await launchUrl(uri, mode: LaunchMode.externalApplication);
        stopwatch.stop();
        
        Logger.performance('Launch URL completed in ${stopwatch.elapsedMilliseconds}ms');
        
        if (launchResult) {
          Logger.state('Launch URL successful for installation');
          return true;
        } else {
          Logger.error('Launch URL failed for installation');
          return false;
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Error installing APK', e, stackTrace);
      return false;
    }
  }
  
  /// Verifies the integrity of a file by calculating its checksum.
  ///
  /// If the expected checksum is provided, it will be used for verification.
  /// If the checksumUrl is provided and the direct verification fails or no checksum is provided,
  /// it will attempt to fetch the checksum from the URL as a fallback.
  ///
  /// Returns true if the calculated checksum matches the expected checksum,
  /// false otherwise.
  Future<bool> _verifyFileIntegrity(String filePath, String algorithm, String? expectedChecksum, {String? checksumUrl}) async {
    Logger.state('Starting file integrity verification');
    Logger.data('File path: $filePath');
    Logger.data('Algorithm: $algorithm');
    Logger.data('Expected checksum: $expectedChecksum');
    Logger.data('Checksum URL: $checksumUrl');
    
    try {
      final file = File(filePath);
      
      // Verify file exists and is readable
      if (!file.existsSync()) {
        Logger.error('File does not exist at path: $filePath');
        return false;
      }
      
      final fileSize = file.lengthSync();
      Logger.data('File size: $fileSize bytes');
      
      // Calculate checksum
      Logger.state('Calculating file checksum');
      final stopwatch = Stopwatch()..start();
      
      final bytes = await file.readAsBytes();
      String calculatedChecksum;
      
      if (algorithm.toLowerCase() == 'sha256') {
        final digest = crypto.sha256.convert(bytes);
        calculatedChecksum = digest.toString();
      } else {
        Logger.error('Unsupported algorithm: $algorithm');
        return false;
      }
      
      stopwatch.stop();
      Logger.performance('Checksum calculated in ${stopwatch.elapsedMilliseconds}ms');
      Logger.data('Calculated checksum: $calculatedChecksum');
      
      // First try direct verification if expected checksum is provided
      if (expectedChecksum != null) {
        final isValid = calculatedChecksum.toLowerCase() == expectedChecksum.toLowerCase();
        
        if (isValid) {
          Logger.state('Checksum verification successful');
          return true;
        } else {
          Logger.error('Direct checksum verification failed');
          Logger.data('Expected: $expectedChecksum');
          Logger.data('Calculated: $calculatedChecksum');
          
          // If checksumUrl is not provided, return false
          if (checksumUrl == null) {
            Logger.error('No checksum URL provided for fallback verification');
            return false;
          }
        }
      } else if (checksumUrl == null) {
        Logger.error('Neither expected checksum nor checksum URL provided');
        return false;
      }
      
      // Try to fetch checksum from URL as fallback
      Logger.state('Attempting to fetch checksum from URL: $checksumUrl');
      final checksumFetchStopwatch = Stopwatch()..start();
      
      try {
        final response = await _httpClient.get(Uri.parse(checksumUrl!));
        checksumFetchStopwatch.stop();
        
        Logger.performance('Checksum fetched in ${checksumFetchStopwatch.elapsedMilliseconds}ms');
        Logger.data('Response status code: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final checksumFileContent = response.body;
          Logger.data('Checksum file content: $checksumFileContent');
          
          // Parse the checksum file to find the relevant checksum
          // Checksum files typically contain lines like: "<checksum> <filename>"
          final fileName = filePath.split('/').last;
          final checksumLines = checksumFileContent.split('\n');
          
          String? fetchedChecksum;
          for (final line in checksumLines) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              final checksum = parts[0];
              final fileNameInLine = parts.sublist(1).join(' ');
              
              if (fileNameInLine.contains(fileName)) {
                fetchedChecksum = checksum;
                Logger.data('Found matching checksum in file: $fetchedChecksum for $fileNameInLine');
                break;
              }
            }
          }
          
          if (fetchedChecksum != null) {
            final isValid = calculatedChecksum.toLowerCase() == fetchedChecksum.toLowerCase();
            
            if (isValid) {
              Logger.state('Checksum verification successful using fetched checksum');
              return true;
            } else {
              Logger.error('Checksum verification failed using fetched checksum');
              Logger.data('Fetched: $fetchedChecksum');
              Logger.data('Calculated: $calculatedChecksum');
              return false;
            }
          } else {
            Logger.error('Could not find matching checksum in fetched file');
            return false;
          }
        } else {
          Logger.error('Failed to fetch checksum file: ${response.statusCode}');
          return false;
        }
      } catch (e, stackTrace) {
        checksumFetchStopwatch.stop();
        Logger.error('Error fetching checksum from URL', e, stackTrace);
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('Error verifying file integrity', e, stackTrace);
      return false;
    }
  }
}
