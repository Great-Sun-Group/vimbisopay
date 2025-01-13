import Flutter
import UIKit
import Firebase
// Uncomment when Apple Developer Program is activated
//import FirebaseMessaging
//import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase first
    FirebaseApp.configure()
    
    /* Uncomment when Apple Developer Program is activated
    // Set up notification handling
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self
    
    // Register for remote notifications
    application.registerForRemoteNotifications()
    */
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  /* Uncomment when Apple Developer Program is activated
  // Handle APNs token refresh
  override func application(_ application: UIApplication,
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("APNS token received: \(token)")
        
    // Set APNS token for Firebase Messaging
    Messaging.messaging().apnsToken = deviceToken
    print("APNS token set successfully")
    
    // Request FCM token after APNS token is set
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      Messaging.messaging().token { fcmToken, error in
        if let error = error {
          print("Error fetching FCM token after APNS token set: \(error)")
        } else if let fcmToken = fcmToken {
          print("FCM token refreshed after APNS token set: \(fcmToken)")
          NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: ["token": fcmToken]
          )
        }
      }
    }
  }
  
  // Handle APNs registration errors
  override func application(_ application: UIApplication,
                          didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error)")
  }
  
  // Handle notification when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .badge, .sound])
  }
  */
}

/* Uncomment when Apple Developer Program is activated
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}
*/
