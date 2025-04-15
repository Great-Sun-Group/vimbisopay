# VimbisoPay Android Development Guide

This guide provides instructions for setting up, running, and troubleshooting the VimbisoPay Flutter app on Android devices.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Configuration Files](#configuration-files)
4. [Running on Android](#running-on-android)
5. [Common Issues and Troubleshooting](#common-issues-and-troubleshooting)
6. [Useful Commands](#useful-commands)

## Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (version 3.29.2 or later)
- **Android SDK** with command-line tools
- **Git**

Make sure Flutter and Android SDK tools are in your PATH:

```bash
# Add to your ~/.bashrc or ~/.zshrc
export PATH="$HOME/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
```

After adding these lines, reload your shell configuration:

```bash
source ~/.bashrc  # or source ~/.zshrc
```

## Initial Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd vimbisopay_app
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Set up Git hooks** (optional but recommended):
   ```bash
   mkdir -p .git/hooks
   ln -s ../../scripts/git-hooks/pre-push .git/hooks/pre-push
   ```

## Configuration Files

The app requires several configuration files that are not checked into version control:

### 1. API Configuration

Create `lib/core/config/api_config.dart` from the example file:

```bash
cp lib/core/config/api_config.dart.example lib/core/config/api_config.dart
```

Edit the file to include your API key:

```dart
class ApiConfig {
  static const String apiKey = 'Your API key here';
  static const String baseUrl = 'https://dev.mycredex.dev';
}
```

### 2. Encryption Configuration

Create `lib/core/config/encryption_config.dart` from the example file:

```bash
cp lib/core/config/encryption_config.dart.example lib/core/config/encryption_config.dart
```

### 3. Firebase Configuration

For Android, place `google-services.json` in `android/app/` directory.

## Running on Android

### Setup Android Device

1. **Enable Developer Options** on your Android device:
   - Go to Settings > About phone
   - Tap "Build number" 7 times to enable Developer options
   - Go back to Settings > System > Developer options
   - Enable "USB debugging"

2. **Connect your device** via USB and authorize the computer when prompted on your device.

3. **Verify device connection**:
   ```bash
   flutter devices
   ```
   Your device should appear in the list.

   If your device is not detected, you can check with ADB:
   ```bash
   adb devices
   ```

### Run the App

```bash
flutter run
```

## Common Issues and Troubleshooting

### Flutter SDK Issues

**Issue**: Flutter command not found
**Solution**: Ensure Flutter is in your PATH:
```bash
export PATH="$HOME/flutter/bin:$PATH"
```

**Issue**: Flutter version incompatibility
**Solution**: Update Flutter:
```bash
flutter upgrade
```

### Android SDK Setup Issues

**Issue**: Android SDK command-line tools not found
**Solution**: Install the command-line tools:
```bash
# Download and set up Android SDK command-line tools
mkdir -p ~/android-cmdline-tools
cd ~/android-cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip
unzip commandlinetools-linux-10406996_latest.zip
mkdir -p ~/android-sdk/cmdline-tools
mv cmdline-tools ~/android-sdk/cmdline-tools/latest
```

**Issue**: Android SDK licenses not accepted
**Solution**: Accept the licenses:
```bash
# Make sure ANDROID_HOME is set and cmdline-tools are in PATH
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"

# Accept all licenses
yes | sdkmanager --licenses
```

**Issue**: Missing Android SDK components
**Solution**: Install the necessary components:
```bash
sdkmanager "platform-tools" "build-tools;29.0.3" "platforms;android-29"
```

**Issue**: Hot reload not working
**Solution**: Make sure you run Flutter with the hot reload flag:
```bash
flutter run --hot
```

### Android Issues

**Issue**: Gradle plugin compatibility error with newer Flutter versions
**Solution**: Update the Flutter Gradle plugin configuration in `android/app/build.gradle`:

1. Move the plugins block to the top of the file:
```gradle
plugins {
    id 'com.android.application'
    id 'kotlin-android'
    id 'com.google.gms.google-services'
    id 'dev.flutter.flutter-gradle-plugin'
}

// Rest of the file...
```

2. Ensure `android/settings.gradle` has the correct plugin loader:
```gradle
pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def flutterSdkPath = properties.getProperty("flutter.sdk")
        assert flutterSdkPath != null, "flutter.sdk not set in local.properties"
        return flutterSdkPath
    }()

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.2.1" apply false
    id "org.jetbrains.kotlin.android" version "1.8.22" apply false
}

include ":app"
```

**Issue**: Device not detected
**Solution**:
- Ensure USB debugging is enabled
- Try a different USB cable or port
- Run `adb devices` to check if the device is recognized
- Restart the adb server:
  ```bash
  adb kill-server
  adb start-server
  ```

**Issue**: Gradle build fails with "SDK location not found"
**Solution**: Create a `local.properties` file in the `android` directory:
```properties
sdk.dir=/path/to/your/Android/sdk
flutter.sdk=/path/to/your/flutter
```

**Issue**: Error about Flutter Gradle plugin application method
**Solution**: This occurs when using a newer version of Flutter with an older project configuration. The error message will look like:
```
You are applying Flutter's main Gradle plugin imperatively using the apply script method, which is not possible anymore. Migrate to applying Gradle plugins with the declarative plugins block
```

To fix this, update your `android/app/build.gradle` file by replacing:
```gradle
apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply plugin: 'com.google.gms.google-services'
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"
```

With:
```gradle
plugins {
    id 'com.android.application'
    id 'kotlin-android'
    id 'com.google.gms.google-services'
    id 'dev.flutter.flutter-gradle-plugin'
}
```

Make sure this plugins block is at the very top of the file, before any other statements.

## Useful Commands

### Flutter Commands

```bash
# Check Flutter installation and dependencies
flutter doctor -v

# Clean the project (useful for resolving build issues)
flutter clean

# Update Flutter packages
flutter pub get

# Run Flutter with verbose logging
flutter run -v

# Build an APK
flutter build apk
```

### Android Commands

```bash
# List connected Android devices
adb devices

# Install APK directly
adb install build/app/outputs/flutter-apk/app-debug.apk

# View Android logs
adb logcat
```

## Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Flutter GitHub Repository](https://github.com/flutter/flutter)
- [Dart Documentation](https://dart.dev/guides)
- [Firebase Flutter Documentation](https://firebase.google.com/docs/flutter/setup)
