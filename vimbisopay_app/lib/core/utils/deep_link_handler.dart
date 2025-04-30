import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';

/// A class for handling deep links in the application.
///
/// This class uses the app_links package to handle deep links and provides
/// a simplified interface for handling verification callbacks.
class DeepLinkHandler {
  /// Callback for when a verification is completed
  static Function(String phone)? onVerificationComplete;
  
  /// The AppLinks instance used for deep link handling
  static AppLinks? _appLinks;
  
  /// Subscription to the app links stream
  static StreamSubscription<Uri>? _linkSubscription;
  
  /// Whether the deep link handler has been initialized
  static bool _initialized = false;
  
  /// Initialize deep link handling.
  ///
  /// This method initializes the AppLinks instance and sets up listeners
  /// for both initial and subsequent deep links.
  static Future<void> initialize() async {
    if (_initialized) {
      Logger.data('[DeepLinkHandler] Already initialized');
      return;
    }
    
    try {
      _appLinks = AppLinks();
      
      // Get the initial link if the app was opened with one
      final initialLink = await _appLinks!.getInitialAppLink();
      if (initialLink != null) {
        Logger.data('[DeepLinkHandler] App opened with initial link: $initialLink');
        _handleDeepLink(initialLink);
      }
      
      // Listen for subsequent links
      _linkSubscription = _appLinks!.uriLinkStream.listen((uri) {
        Logger.data('[DeepLinkHandler] Received app link: $uri');
        _handleDeepLink(uri);
      }, onError: (error) {
        Logger.error('[DeepLinkHandler] Error receiving app link', error);
      });
      
      _initialized = true;
      Logger.data('[DeepLinkHandler] Deep link handling initialized');
    } catch (e) {
      Logger.error('[DeepLinkHandler] Error initializing deep link handling', e);
    }
  }
  
  /// Register a callback for when a verification is completed.
  ///
  /// This method should be called by the WhatsAppOTPVerification widget to register
  /// a callback that will be called when verification is completed.
  static void registerVerificationCallback(Function(String phone) callback) {
    onVerificationComplete = callback;
    Logger.data('[DeepLinkHandler] Verification callback registered');
  }
  
  /// Unregister the verification callback.
  ///
  /// This method should be called when the WhatsAppOTPVerification widget is disposed.
  static void unregisterVerificationCallback() {
    onVerificationComplete = null;
    Logger.data('[DeepLinkHandler] Verification callback unregistered');
  }
  
  /// Manually trigger the verification callback.
  ///
  /// This method can be used to simulate a deep link being received.
  static void triggerVerificationCallback(String phone) {
    if (onVerificationComplete != null) {
      Logger.data('[DeepLinkHandler] Manually triggering verification callback for phone: $phone');
      onVerificationComplete!(phone);
    } else {
      Logger.data('[DeepLinkHandler] No verification callback registered');
    }
  }
  
  /// Handle a deep link URI.
  ///
  /// This method parses the URI and performs the appropriate action based on the link.
  static void _handleDeepLink(Uri uri) {
    try {
      // Check if this is a verification deep link
      if (uri.path == 'verification-complete' || uri.path == '/verification-complete') {
        _handleVerificationDeepLink(uri);
      } else {
        Logger.data('[DeepLinkHandler] Unknown deep link path: ${uri.path}');
      }
    } catch (e) {
      Logger.error('[DeepLinkHandler] Error handling deep link', e);
    }
  }
  
  /// Handle a verification deep link.
  ///
  /// This method extracts the phone number from the URI and calls the verification callback.
  static void _handleVerificationDeepLink(Uri uri) {
    try {
      final phone = uri.queryParameters['phone'];
      final status = uri.queryParameters['status'];
      
      Logger.data('[DeepLinkHandler] Verification deep link received:');
      Logger.data('  - Phone: $phone');
      Logger.data('  - Status: $status');
      
      if (phone != null && status == 'success') {
        if (onVerificationComplete != null) {
          Logger.data('[DeepLinkHandler] Calling verification callback');
          onVerificationComplete!(phone);
        } else {
          Logger.data('[DeepLinkHandler] No verification callback registered');
        }
      } else {
        Logger.data('[DeepLinkHandler] Invalid verification parameters');
      }
    } catch (e) {
      Logger.error('[DeepLinkHandler] Error handling verification deep link', e);
    }
  }
  
  /// Dispose of resources.
  ///
  /// This method should be called when the app is shutting down.
  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _initialized = false;
    Logger.data('[DeepLinkHandler] Deep link handling disposed');
  }
}
