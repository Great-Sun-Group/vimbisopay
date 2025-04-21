import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/analytics/analytics_event.dart';
import 'package:vimbisopay_app/domain/entities/analytics/event_types.dart';
import 'package:vimbisopay_app/domain/repositories/analytics/analytics_provider.dart';

/// Service for tracking analytics events.
///
/// This service provides methods for tracking various types of events
/// and delegates the actual tracking to one or more [AnalyticsProvider]s.
class AnalyticsService {
  /// The list of analytics providers.
  final List<AnalyticsProvider> _providers;

  /// Whether analytics tracking is enabled.
  bool _isEnabled = true;

  /// Creates a new analytics service.
  ///
  /// [providers] is the list of analytics providers to use.
  AnalyticsService(this._providers);

  /// Initializes the analytics service.
  ///
  /// This method initializes all the analytics providers.
  /// Returns a [Future] that completes when all providers are initialized.
  Future<void> initialize() async {
    try {
      Logger.data('Initializing analytics service with ${_providers.length} providers');
      
      for (final provider in _providers) {
        try {
          await provider.initialize();
          Logger.data('Initialized analytics provider: ${provider.providerName}');
        } catch (e, stackTrace) {
          Logger.error('Failed to initialize analytics provider: ${provider.providerName}', e, stackTrace);
        }
      }
      
      Logger.data('Analytics service initialized');
    } catch (e, stackTrace) {
      Logger.error('Failed to initialize analytics service', e, stackTrace);
      rethrow;
    }
  }

  /// Enables or disables analytics tracking.
  ///
  /// [isEnabled] is whether analytics tracking should be enabled.
  void setEnabled(bool isEnabled) {
    _isEnabled = isEnabled;
    Logger.data('Analytics tracking ${isEnabled ? 'enabled' : 'disabled'}');
  }

  /// Tracks an analytics event.
  ///
  /// [event] is the event to track.
  /// Returns a [Future] that completes when the event is tracked by all providers.
  Future<void> trackEvent(AnalyticsEvent event) async {
    if (!_isEnabled) return;
    
    try {
      for (final provider in _providers) {
        try {
          await provider.trackEvent(event);
        } catch (e, stackTrace) {
          Logger.error('Failed to track event with provider: ${provider.providerName}', e, stackTrace);
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to track event', e, stackTrace);
    }
  }

  /// Tracks a screen view.
  ///
  /// [screenName] is the name of the screen being viewed.
  /// [parameters] is a map of additional parameters associated with the event.
  /// Returns a [Future] that completes when the event is tracked.
  Future<void> trackScreenView(String screenName, {Map<String, dynamic> parameters = const {}}) async {
    await trackEvent(ScreenViewEvent(screenName, parameters: parameters));
    
    // Also set the current screen on all providers
    if (_isEnabled) {
      for (final provider in _providers) {
        try {
          await provider.setCurrentScreen(screenName);
        } catch (e, stackTrace) {
          Logger.error('Failed to set current screen with provider: ${provider.providerName}', e, stackTrace);
        }
      }
    }
  }

  /// Tracks a button tap.
  ///
  /// [buttonId] is the identifier of the button being tapped.
  /// [screenName] is the name of the screen where the button is located.
  /// [parameters] is a map of additional parameters associated with the event.
  /// Returns a [Future] that completes when the event is tracked.
  Future<void> trackButtonTap(String buttonId, {required String screenName, Map<String, dynamic> parameters = const {}}) async {
    await trackEvent(ButtonTapEvent(buttonId, screenName: screenName, parameters: parameters));
  }

  /// Tracks an API error.
  ///
  /// [endpoint] is the API endpoint that returned the error.
  /// [statusCode] is the HTTP status code of the error.
  /// [errorMessage] is the error message.
  /// [parameters] is a map of additional parameters associated with the event.
  /// Returns a [Future] that completes when the event is tracked.
  Future<void> trackApiError({
    required String endpoint,
    required int statusCode,
    required String errorMessage,
    Map<String, dynamic> parameters = const {},
  }) async {
    await trackEvent(ApiErrorEvent(
      endpoint: endpoint,
      statusCode: statusCode,
      errorMessage: errorMessage,
      parameters: parameters,
    ));
  }

  /// Tracks an app crash.
  ///
  /// [exception] is the exception that caused the crash.
  /// [stackTrace] is the stack trace of the crash.
  /// [parameters] is a map of additional parameters associated with the event.
  /// Returns a [Future] that completes when the event is tracked.
  Future<void> trackCrash({
    required dynamic exception,
    required StackTrace stackTrace,
    Map<String, dynamic> parameters = const {},
  }) async {
    final exceptionString = exception.toString();
    final stackTraceString = stackTrace.toString();
    
    await trackEvent(CrashEvent(
      exception: exceptionString,
      stackTrace: stackTraceString,
      parameters: parameters,
    ));
    
    // Also log the error with all providers
    if (_isEnabled) {
      for (final provider in _providers) {
        try {
          await provider.logError(exception, stackTrace);
        } catch (e, stackTrace) {
          Logger.error('Failed to log error with provider: ${provider.providerName}', e, stackTrace);
        }
      }
    }
  }

  /// Tracks a custom event.
  ///
  /// [eventName] is the name of the custom event.
  /// [parameters] is a map of additional parameters associated with the event.
  /// Returns a [Future] that completes when the event is tracked.
  Future<void> trackCustomEvent(String eventName, {Map<String, dynamic> parameters = const {}}) async {
    await trackEvent(CustomEvent(eventName, parameters: parameters));
  }

  /// Sets user properties.
  ///
  /// [properties] is a map of user properties to set.
  /// Returns a [Future] that completes when the properties are set.
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    if (!_isEnabled) return;
    
    try {
      for (final provider in _providers) {
        try {
          await provider.setUserProperties(properties);
        } catch (e, stackTrace) {
          Logger.error('Failed to set user properties with provider: ${provider.providerName}', e, stackTrace);
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to set user properties', e, stackTrace);
    }
  }

  /// Resets all analytics data.
  ///
  /// This method clears all user data and resets the analytics session.
  /// Returns a [Future] that completes when the data is reset.
  Future<void> resetAnalyticsData() async {
    if (!_isEnabled) return;
    
    try {
      for (final provider in _providers) {
        try {
          await provider.resetAnalyticsData();
        } catch (e, stackTrace) {
          Logger.error('Failed to reset analytics data with provider: ${provider.providerName}', e, stackTrace);
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to reset analytics data', e, stackTrace);
    }
  }
}
