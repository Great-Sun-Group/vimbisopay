import 'package:vimbisopay_app/domain/entities/analytics/analytics_event.dart';

/// Interface for analytics providers.
///
/// This interface defines the contract that all analytics providers must implement.
/// It provides methods for tracking events, setting user properties, and more.
abstract class AnalyticsProvider {
  /// The name of the provider.
  String get providerName;

  /// Initializes the analytics provider.
  ///
  /// This method should be called before using the provider.
  /// Returns a [Future] that completes when the provider is initialized.
  Future<void> initialize();

  /// Tracks an analytics event.
  ///
  /// [event] is the event to track.
  /// Returns a [Future] that completes when the event is tracked.
  Future<void> trackEvent(AnalyticsEvent event);

  /// Sets user properties.
  ///
  /// [properties] is a map of user properties to set.
  /// Returns a [Future] that completes when the properties are set.
  Future<void> setUserProperties(Map<String, dynamic> properties);

  /// Sets the current screen.
  ///
  /// [screenName] is the name of the current screen.
  /// [screenClassOverride] is an optional class name for the screen.
  /// Returns a [Future] that completes when the screen is set.
  Future<void> setCurrentScreen(String screenName, {String? screenClassOverride});

  /// Logs an error.
  ///
  /// [exception] is the exception that occurred.
  /// [stackTrace] is the stack trace of the exception.
  /// Returns a [Future] that completes when the error is logged.
  Future<void> logError(dynamic exception, StackTrace stackTrace);

  /// Resets all analytics data.
  ///
  /// This method should clear all user data and reset the analytics session.
  /// Returns a [Future] that completes when the data is reset.
  Future<void> resetAnalyticsData();
}
