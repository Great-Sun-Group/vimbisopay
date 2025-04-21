import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

/// Utility class for tracking API errors.
///
/// This class provides methods for tracking API errors using the analytics service.
class ApiErrorTracker {
  /// Tracks an API error.
  ///
  /// [endpoint] is the API endpoint that returned the error.
  /// [statusCode] is the HTTP status code of the error.
  /// [errorMessage] is the error message.
  /// [parameters] is a map of additional parameters associated with the error.
  static void trackError({
    required String endpoint,
    required int statusCode,
    required String errorMessage,
    Map<String, dynamic> parameters = const {},
  }) {
    try {
      final analyticsService = ServiceLocator.analyticsService;
      analyticsService.trackApiError(
        endpoint: endpoint,
        statusCode: statusCode,
        errorMessage: errorMessage,
        parameters: parameters,
      );
    } catch (e) {
      Logger.error('Failed to track API error', e);
    }
  }

  /// Tracks an API exception.
  ///
  /// [endpoint] is the API endpoint that threw the exception.
  /// [exception] is the exception that was thrown.
  /// [stackTrace] is the stack trace of the exception.
  /// [parameters] is a map of additional parameters associated with the error.
  static void trackException({
    required String endpoint,
    required dynamic exception,
    required StackTrace stackTrace,
    Map<String, dynamic> parameters = const {},
  }) {
    try {
      // Log the error first
      Logger.error('API Exception for $endpoint', exception, stackTrace);
      
      // Track the error with analytics
      final analyticsService = ServiceLocator.analyticsService;
      analyticsService.trackApiError(
        endpoint: endpoint,
        statusCode: 0, // Unknown status code for exceptions
        errorMessage: exception.toString(),
        parameters: {
          ...parameters,
          'stack_trace': stackTrace.toString(),
        },
      );
      
      // Also track as a crash event
      analyticsService.trackCrash(
        exception: exception,
        stackTrace: stackTrace,
        parameters: {
          'endpoint': endpoint,
          ...parameters,
        },
      );
    } catch (e) {
      Logger.error('Failed to track API exception', e);
    }
  }
}
