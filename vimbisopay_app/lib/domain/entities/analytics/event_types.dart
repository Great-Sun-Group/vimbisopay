import 'package:vimbisopay_app/domain/entities/analytics/analytics_event.dart';

/// Event for tracking screen views.
class ScreenViewEvent extends AnalyticsEvent {
  /// Creates a new screen view event.
  ///
  /// [screenName] is the name of the screen being viewed.
  /// [parameters] is a map of additional parameters associated with the event.
  ScreenViewEvent(
    String screenName, {
    Map<String, dynamic> parameters = const {},
  }) : super(
          name: 'screen_view',
          parameters: {
            'screen_name': screenName,
            ...parameters,
          },
        );
}

/// Event for tracking button taps.
class ButtonTapEvent extends AnalyticsEvent {
  /// Creates a new button tap event.
  ///
  /// [buttonId] is the identifier of the button being tapped.
  /// [screenName] is the name of the screen where the button is located.
  /// [parameters] is a map of additional parameters associated with the event.
  ButtonTapEvent(
    String buttonId, {
    required String screenName,
    Map<String, dynamic> parameters = const {},
  }) : super(
          name: 'button_tap',
          parameters: {
            'button_id': buttonId,
            'screen_name': screenName,
            ...parameters,
          },
        );
}

/// Event for tracking API errors.
class ApiErrorEvent extends AnalyticsEvent {
  /// Creates a new API error event.
  ///
  /// [endpoint] is the API endpoint that returned the error.
  /// [statusCode] is the HTTP status code of the error.
  /// [errorMessage] is the error message.
  /// [parameters] is a map of additional parameters associated with the event.
  ApiErrorEvent({
    required String endpoint,
    required int statusCode,
    required String errorMessage,
    Map<String, dynamic> parameters = const {},
  }) : super(
          name: 'api_error',
          parameters: {
            'endpoint': endpoint,
            'status_code': statusCode,
            'error_message': errorMessage,
            ...parameters,
          },
        );
}

/// Event for tracking app crashes.
class CrashEvent extends AnalyticsEvent {
  /// Creates a new crash event.
  ///
  /// [exception] is the exception that caused the crash.
  /// [stackTrace] is the stack trace of the crash.
  /// [parameters] is a map of additional parameters associated with the event.
  CrashEvent({
    required String exception,
    required String stackTrace,
    Map<String, dynamic> parameters = const {},
  }) : super(
          name: 'app_crash',
          parameters: {
            'exception': exception,
            'stack_trace': stackTrace,
            ...parameters,
          },
        );
}

/// Event for tracking custom events.
class CustomEvent extends AnalyticsEvent {
  /// Creates a new custom event.
  ///
  /// [eventName] is the name of the custom event.
  /// [parameters] is a map of additional parameters associated with the event.
  CustomEvent(
    String eventName, {
    Map<String, dynamic> parameters = const {},
  }) : super(
          name: eventName,
          parameters: parameters,
        );
}
