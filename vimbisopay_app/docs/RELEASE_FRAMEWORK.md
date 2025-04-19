# VimbisoPay Release Framework

This document outlines the comprehensive release framework for the VimbisoPay app, including both release and debug builds, API environment configuration, and version management.

## Table of Contents

1. [Version Management](#version-management)
2. [Build Types](#build-types)
3. [API Environment Configuration](#api-environment-configuration)
4. [Release Process](#release-process)
5. [Debug Build Process](#debug-build-process)
6. [GitHub Release Structure](#github-release-structure)
7. [App Update Service](#app-update-service)
8. [Developer Tools](#developer-tools)
9. [Debug App Icon](#debug-app-icon)
10. [Firebase Configuration](#firebase-configuration)
11. [Implementation Plan](#implementation-plan)

## Version Management

### Version Format

- **Release Builds**: `x.y.z+b`
  - `x.y.z` = Semantic version (major.minor.patch)
  - `b` = Build number (incremental)
  - Example: `2.9.1+3`

- **Debug Builds**: `x.y.z-debug+b`
  - Same structure as release builds with `-debug` suffix
  - Example: `2.9.1-debug+3`

### Version Storage

Versions are stored in:
1. `pubspec.yaml` - Main version definition
2. `android/local.properties` - Android-specific version
3. `apk-builds/vimbisopay-{version}.json` - Version metadata for app updates

### Version Incrementing Rules

- **Major Version (x)**: Significant changes, major UI overhauls, or breaking changes
- **Minor Version (y)**: New features or substantial improvements
- **Patch Version (z)**: Bug fixes and minor improvements
- **Build Number (b)**: Incremented with each build, regardless of version changes

Debug and release builds maintain separate version tracks:
- Release builds: `2.9.0+1` → `2.9.0+2` → `2.9.1+3`
- Debug builds: `2.9.0-debug+101` → `2.9.0-debug+102` → `2.9.1-debug+103`

## Build Types

### Release Builds

- Production-ready builds
- Always point to production API
- Optimized for performance and size
- No debugging tools or features
- Distributed through official channels
- Package name: `com.vimbisopay.vimbisopay_app`

### Debug Builds

- Development and testing builds
- Can point to either development or production API
- Include debugging tools and features
- May include additional logging
- Distributed through GitHub releases as pre-releases
- Package name: `com.vimbisopay.vimbisopay_app.debug` (automatically applied via build.gradle)
- Can be installed alongside release builds due to different package name
- App name is prefixed with "[DEBUG]" for easy identification (using `tools:replace="android:label"` in debug AndroidManifest.xml)
- App icon includes a red debug badge (when using the debug icon script)

## API Environment Configuration

### Environment Types

1. **Development Environment**
   - URL: `https://dev.mycredex.dev`
   - Used for development and testing
   - May contain experimental features

2. **Production Environment**
   - URL: `https://api.vimbisopay.com`
   - Used for production releases
   - Stable and reliable

### Configuration System

The API configuration system will be enhanced to support multiple environments:

```dart
// lib/core/config/api_config.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ApiEnvironment {
  development,
  production,
}

class ApiConfig {
  static ApiEnvironment _environment = kReleaseMode 
      ? ApiEnvironment.production 
      : ApiEnvironment.development;
  
  static const String _prefKey = 'api_environment';
  static bool _initialized = false;
  
  // Initialize from SharedPreferences
  static Future<void> initialize() async {
    if (_initialized || kReleaseMode) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final envString = prefs.getString(_prefKey);
      
      if (envString != null) {
        _environment = ApiEnvironment.values.firstWhere(
          (e) => e.toString() == envString,
          orElse: () => ApiEnvironment.development,
        );
      }
      
      _initialized = true;
    } catch (e) {
      // Fallback to default
      _environment = ApiEnvironment.development;
    }
  }
  
  // Can be overridden for debug builds
  static Future<void> setEnvironment(ApiEnvironment env) async {
    // Only allow overriding in debug mode
    if (kReleaseMode) return;
    
    _environment = env;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, env.toString());
    } catch (e) {
      // Handle error
    }
  }
  
  static ApiEnvironment get environment => _environment;
  
  static String get apiKey {
    switch (_environment) {
      case ApiEnvironment.development:
        return 'gfnsrtj543dGJFDGjffDhjdyKGjugDg436vBNb';
      case ApiEnvironment.production:
        return 'prod-api-key-here';
    }
  }
  
  static String get baseUrl {
    switch (_environment) {
      case ApiEnvironment.development:
        return 'https://dev.mycredex.dev';
      case ApiEnvironment.production:
        return 'https://api.vimbisopay.com';
    }
  }
  
  static String get environmentName {
    switch (_environment) {
      case ApiEnvironment.development:
        return 'Development';
      case ApiEnvironment.production:
        return 'Production';
    }
  }
}
```

## Release Process

### Release Build Process

The release build process uses the `update-version.sh` script:

1. **Version Update**
   - Update version in `pubspec.yaml`
   - Update version in `android/local.properties`
   - Update `CHANGELOG.md`

2. **Signing Verification**
   - Verify the existence of the release keystore file
   - Verify the existence of the key.properties file
   - See [RELEASE_SIGNING_KEYS.md](RELEASE_SIGNING_KEYS.md) for details on the signing process

3. **Build Process**
   - Build universal APK with release signing
   - Build architecture-specific APKs with release signing
   - Verify APK signatures
   - Generate checksums

4. **GitHub Release**
   - Create Git tag
   - Create GitHub release
   - Upload APKs and metadata
   - Update version JSON file

5. **Verification**
   - Verify APK installation
   - Verify update mechanism

### Command

```bash
./scripts/update-version.sh
```

## Debug Build Process

The debug build process uses the new `update-debug-version.sh` script:

1. **Version Update**
   - Update version in `pubspec.yaml` with debug suffix
   - Update version in `android/local.properties`
   - Set build mode to debug

2. **API Environment**
   - Specify target API environment (dev or prod)
   - Include environment information in metadata

3. **Build Process**
   - Add ".debug" suffix to application ID
   - Build debug APK
   - Generate version-specific filename

4. **GitHub Release**
   - Create Git tag with debug prefix
   - Create GitHub pre-release
   - Upload APK and metadata
   - Update debug version JSON file

### Command

```bash
./scripts/update-debug-version.sh --api-env [dev|prod] --priority [low|medium|high|critical] --type [patch|minor|major] --min-version [x.y.z]
```

#### Parameters

- `--api-env`: Specifies the API environment to use (dev or prod)
- `--priority`: Sets the update priority (low, medium, high, critical)
- `--type`: Sets the update type (patch, minor, major)
- `--min-version`: Sets the minimum required version (x.y.z)

## GitHub Release Structure

### Release Builds

- **Tag Format**: `v2.9.1+3`
- **Release Name**: `Release v2.9.1+3`
- **Release Type**: Standard release
- **Assets**:
  - `vimbisopay-2.9.1-3.apk` (Universal)
  - `vimbisopay-2.9.1-3-arm64.apk` (ARM64)
  - `vimbisopay-2.9.1-3-arm.apk` (ARM)
  - `vimbisopay-2.9.1-3-x86_64.apk` (x86_64)
  - `vimbisopay-2.9.1-3-checksums.txt`
  - `vimbisopay-2.9.1+3.json`

### Debug Builds

- **Tag Format**: `debug-v2.9.1-debug-3`
- **Release Name**: `Debug Release 2.9.1-debug+3`
- **Release Type**: Pre-release
- **Assets**:
  - `vimbisopay-2.9.1-debug-3.apk` (Universal)
  - `vimbisopay-2.9.1-debug-3-arm64.apk` (ARM64)
  - `vimbisopay-2.9.1-debug-3-arm.apk` (ARM)
  - `vimbisopay-2.9.1-debug-3-x86_64.apk` (x86_64)
  - `vimbisopay-2.9.1-debug-3-checksums.txt`
  - `vimbisopay-2.9.1-debug+3.json`

## App Update Service

The app update service has been enhanced to handle both release and debug builds:

1. **Build Type Detection**
   - Detect current build type (release or debug)
   - Only show relevant updates
   - For API requests, the "-debug" suffix is automatically stripped from the version name to ensure compatibility with the version check API

2. **Version Comparison**
   - Compare semantic versions correctly
   - Handle debug suffix appropriately

3. **Update Channels**
   - Release builds only update to newer release builds
   - Debug builds can update to newer debug builds
   - Debug builds show API environment information

4. **Update Metadata**
   - Include build type and API environment in metadata
   - Display environment information in update dialog

## Developer Tools

### Debug Screen Enhancements

The debug screen will be enhanced to include:

1. **API Environment Selector**
   - Toggle between development and production APIs
   - Display current API environment
   - Show base URL for current environment

2. **Version Information**
   - Display build type (debug/release)
   - Show version name and code
   - Display API environment

3. **Update Testing**
   - Test update mechanism for debug builds
   - Force check for updates
   - View available debug updates

### Implementation

```dart
// In debug_screen.dart
Widget _buildApiEnvironmentSelector() {
  return Card(
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'API Environment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Current: ${ApiConfig.environmentName}',
                style: TextStyle(
                  fontSize: 14,
                  color: ApiConfig.environment == ApiEnvironment.production
                      ? AppColors.success
                      : AppColors.yellowPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Base URL: ${ApiConfig.baseUrl}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await ApiConfig.setEnvironment(ApiEnvironment.development);
                    setState(() {});
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: ApiConfig.environment == ApiEnvironment.development
                        ? AppColors.yellowPrimary
                        : AppColors.surface,
                    foregroundColor: ApiConfig.environment == ApiEnvironment.development
                        ? AppColors.white
                        : AppColors.textSecondary,
                  ),
                  child: const Text('Development'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await ApiConfig.setEnvironment(ApiEnvironment.production);
                    setState(() {});
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: ApiConfig.environment == ApiEnvironment.production
                        ? AppColors.success
                        : AppColors.surface,
                    foregroundColor: ApiConfig.environment == ApiEnvironment.production
                        ? AppColors.white
                        : AppColors.textSecondary,
                  ),
                  child: const Text('Production'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

## Debug App Icon

To make it easier to distinguish between debug and release builds, we've implemented two visual indicators:

1. The app name is prefixed with "[DEBUG]" in the debug builds (via the debug AndroidManifest.xml)
2. A red debug badge can be added to the app icon using the provided script

### Using the Debug Icon Script

The `create_debug_icons.sh` script creates debug-specific versions of the app icons with a red badge:

```bash
# Make the script executable (if needed)
chmod +x scripts/create_debug_icons.sh

# Run the script to create debug icons
./scripts/create_debug_icons.sh
```

This script:
1. Creates debug-specific resource directories
2. Copies the original app icons to these directories
3. Adds a red badge with "D" text to each icon
4. The Android build system will automatically use these icons for debug builds

### Requirements

The script requires ImageMagick to be installed:
- macOS: `brew install imagemagick`
- Linux: `apt-get install imagemagick`

### How It Works

Android's resource merging system automatically prioritizes resources in the build-type-specific directories over the main resources. By placing modified icons in the `android/app/src/debug/res/mipmap-*` directories, they will only be used for debug builds, while release builds will continue to use the original icons.

## Firebase Configuration

For Firebase functionality to work correctly with both release and debug builds, the `google-services.json` file needs to include both package names:

1. **Release Package Name**: `com.vimbisopay.vimbisopay_app`
2. **Debug Package Name**: `com.vimbisopay.vimbisopay_app.debug`

When setting up a new Firebase project or updating an existing one:

1. Go to the Firebase Console (https://console.firebase.google.com/)
2. Select your project
3. Add both Android apps with their respective package names
4. Download the updated `google-services.json` file that includes both configurations
5. Replace the existing file in `android/app/google-services.json`

Alternatively, you can manually add the debug package name to the existing `google-services.json` file by duplicating the client entry and changing the package name:

```json
"client": [
  {
    "client_info": {
      "mobilesdk_app_id": "1:123456789012:android:abcdef1234567890",
      "android_client_info": {
        "package_name": "com.vimbisopay.vimbisopay_app"
      }
    },
    // ... other configuration ...
  },
  {
    "client_info": {
      "mobilesdk_app_id": "1:123456789012:android:abcdef1234567890",
      "android_client_info": {
        "package_name": "com.vimbisopay.vimbisopay_app.debug"
      }
    },
    // ... same configuration as above ...
  }
]
```

## Implementation Plan

### Phase 1: API Environment Configuration

1. Modify `ApiConfig` class to support multiple environments
2. Add environment persistence using SharedPreferences
3. Update app initialization to load environment configuration
4. Add environment indicator for debug builds

### Phase 2: Debug Build Script

1. Create `update-debug-version.sh` script
2. Implement version management for debug builds
3. Add API environment parameter
4. Set up GitHub pre-release creation

### Phase 3: App Update Service Enhancements

1. Modify `AppUpdateService` to handle different build types
2. Update version comparison logic
3. Enhance update dialog to show build type and environment
4. Implement separate update channels

### Phase 4: Debug Screen Enhancements

1. Add API environment selector to debug screen
2. Display current environment and base URL
3. Add build type information
4. Implement environment switching functionality

### Phase 5: Documentation and Testing

1. Create comprehensive documentation
2. Test debug builds with different API environments
3. Verify update mechanism for both build types
4. Document release and debug build processes

### Timeline

- Phase 1: 1-2 days
- Phase 2: 1-2 days
- Phase 3: 2-3 days
- Phase 4: 1-2 days
- Phase 5: 1-2 days

Total estimated time: 6-11 days

## Conclusion

This release framework provides a comprehensive solution for managing both release and debug builds of the VimbisoPay app. By implementing separate version tracks, configurable API environments, and enhanced update mechanisms, the framework supports the requirements for:

1. Debug builds that can point to either dev or prod APIs
2. Release builds that only point to prod APIs
3. Separate version management for release and debug builds

The framework leverages GitHub releases for both build types, providing a centralized and consistent distribution mechanism while clearly differentiating between production and development builds.
