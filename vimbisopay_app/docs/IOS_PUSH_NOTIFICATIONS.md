# Enabling iOS Push Notifications

This guide outlines the steps needed to enable push notifications for the iOS app after enrolling in the Apple Developer Program.

## Prerequisites

1. Active Apple Developer Program membership ($99/year)
2. Access to Apple Developer account
3. Xcode installed on your development machine
4. Firebase project configured (already done)

## Steps

### 1. Apple Developer Portal Setup

1. Log in to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to "Certificates, Identifiers & Profiles"
3. Create an App ID (if not already created):
   - Go to "Identifiers" > "+" > "App IDs"
   - Choose "App" as the type
   - Enter description and bundle ID (com.vimbisopay.vimbisopayApp)
   - Enable "Push Notifications" capability
   - Save the App ID

4. Create a Push Notification Key:
   - Go to "Keys" > "+"
   - Enable "Apple Push Notifications service (APNs)"
   - Register the key and download it (save securely, can only be downloaded once)

### 2. Firebase Configuration

1. Log in to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Project Settings > Cloud Messaging
4. Under "iOS app configuration":
   - Upload the APNs key downloaded from Apple Developer Portal
   - Add the Key ID and Team ID from Apple Developer Portal

### 3. Xcode Project Configuration

1. Open Xcode
2. Select the Runner target
3. Under "Signing & Capabilities":
   - Sign in with your Apple Developer Account
   - Select your team with Apple Developer Program membership
   - Verify the bundle identifier matches your App ID

### 4. Enable Push Notifications in Code

1. Uncomment push notification capabilities in `ios/Runner/Runner.entitlements`:
   ```xml
   <key>aps-environment</key>
   <string>development</string>
   <key>com.apple.developer.usernotifications.time-sensitive</key>
   <true/>
   ```

2. Uncomment push notification configurations in `ios/Runner/Info.plist`:
   ```xml
   <key>NSRemoteNotificationUsageDescription</key>
   <string>We need to send you notifications about your transactions and account updates</string>
   <key>UIBackgroundModes</key>
   <array>
       <string>fetch</string>
       <string>remote-notification</string>
   </array>
   <key>FirebaseAppDelegateProxyEnabled</key>
   <false/>
   ```

3. Uncomment Firebase Cloud Messaging and APNs code in `ios/Runner/AppDelegate.swift`:
   - Uncomment the import statements for FirebaseMessaging and UserNotifications
   - Uncomment the notification setup code in `didFinishLaunchingWithOptions`
   - Uncomment the APNs token handling methods
   - Uncomment the MessagingDelegate extension

### 5. Testing Push Notifications

1. Build and run the app on a physical iOS device
2. Check the Xcode console for successful registration messages:
   - "APNS token received: [token]"
   - "APNS token set successfully"
   - "FCM token refreshed after APNS token set: [token]"

3. Send a test notification:
   - Use Firebase Console > Cloud Messaging > Send your first message
   - Or use the Firebase Admin SDK in your backend to send a test notification

### Troubleshooting

If push notifications aren't working:

1. Verify APNs setup in Apple Developer Portal
2. Check Firebase Console for proper APNs key configuration
3. Ensure the device is using a production build (not a simulator)
4. Check Xcode console for any registration errors
5. Verify the app has permission to send notifications (device Settings)

## Additional Resources

- [Firebase iOS Push Notification Setup Guide](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Apple Push Notification Documentation](https://developer.apple.com/documentation/usernotifications)
- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
