import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/analytics/analytics_event.dart';
import 'package:vimbisopay_app/domain/repositories/analytics/analytics_provider.dart';

/// Firebase implementation of the [AnalyticsProvider] interface.
///
/// This provider uses Firebase Analytics to track events.
class FirebaseAnalyticsProvider implements AnalyticsProvider {
  /// The Firebase Analytics instance.
  final FirebaseAnalytics _analytics;

  /// Creates a new Firebase Analytics provider.
  ///
  /// [analytics] is the Firebase Analytics instance to use.
  FirebaseAnalyticsProvider(this._analytics);

  @override
  String get providerName => 'firebase';

  @override
  Future<void> initialize() async {
    try {
      // Enable analytics collection
      await _analytics.setAnalyticsCollectionEnabled(true);
      Logger.data('Firebase Analytics provider initialized');
    } catch (e, stackTrace) {
      Logger.error('Failed to initialize Firebase Analytics provider', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> trackEvent(AnalyticsEvent event) async {
    try {
      // Convert the event parameters to a format that Firebase Analytics can use
      final parameters = _sanitizeParameters(event.parameters);
      
      // Log the event to Firebase Analytics
      await _analytics.logEvent(
        name: event.name,
        parameters: parameters,
      );
      
      Logger.data('Event tracked with Firebase Analytics: ${event.name}');
    } catch (e, stackTrace) {
      Logger.error('Failed to track event with Firebase Analytics', e, stackTrace);
    }
  }

  @override
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    try {
      // Set each user property individually
      for (final entry in properties.entries) {
        final value = entry.value;
        if (value != null) {
          await _analytics.setUserProperty(
            name: entry.key,
            value: value.toString(),
          );
        }
      }
      
      Logger.data('User properties set with Firebase Analytics');
    } catch (e, stackTrace) {
      Logger.error('Failed to set user properties with Firebase Analytics', e, stackTrace);
    }
  }

  @override
  Future<void> setCurrentScreen(String screenName, {String? screenClassOverride}) async {
    try {
      if (screenClassOverride != null) {
        await _analytics.setCurrentScreen(
          screenName: screenName,
          screenClassOverride: screenClassOverride,
        );
      } else {
        await _analytics.setCurrentScreen(
          screenName: screenName,
        );
      }
      
      Logger.data('Current screen set with Firebase Analytics: $screenName');
    } catch (e, stackTrace) {
      Logger.error('Failed to set current screen with Firebase Analytics', e, stackTrace);
    }
  }

  @override
  Future<void> logError(dynamic exception, StackTrace stackTrace) async {
    try {
      await _analytics.logEvent(
        name: 'custom_app_exception',
        parameters: {
          'exception': exception.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );
      
      Logger.data('Error logged with Firebase Analytics');
    } catch (e, stackTrace) {
      Logger.error('Failed to log error with Firebase Analytics', e, stackTrace);
    }
  }

  @override
  Future<void> resetAnalyticsData() async {
    try {
      await _analytics.resetAnalyticsData();
      Logger.data('Analytics data reset with Firebase Analytics');
    } catch (e, stackTrace) {
      Logger.error('Failed to reset analytics data with Firebase Analytics', e, stackTrace);
    }
  }

  /// Sanitizes parameters to ensure they are compatible with Firebase Analytics.
  ///
  /// Firebase Analytics has restrictions on parameter values:
  /// - String values must be less than 100 characters
  /// - Numeric values must be within certain ranges
  /// - Arrays and nested objects are not supported
  ///
  /// This method ensures that all parameters meet these requirements.
  Map<String, dynamic> _sanitizeParameters(Map<String, dynamic> parameters) {
    final sanitizedParameters = <String, dynamic>{};
    
    for (final entry in parameters.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value == null) {
        // Skip null values
        continue;
      } else if (value is String) {
        // Truncate strings that are too long
        sanitizedParameters[key] = value.length > 100 ? value.substring(0, 100) : value;
      } else if (value is num) {
        // Use as is for numeric values
        sanitizedParameters[key] = value;
      } else if (value is bool) {
        // Convert booleans to strings
        sanitizedParameters[key] = value.toString();
      } else if (value is List) {
        // Convert lists to strings
        sanitizedParameters[key] = value.toString();
      } else if (value is Map) {
        // Convert maps to strings
        sanitizedParameters[key] = value.toString();
      } else {
        // Convert other types to strings
        sanitizedParameters[key] = value.toString();
      }
    }
    
    return sanitizedParameters;
  }
}
