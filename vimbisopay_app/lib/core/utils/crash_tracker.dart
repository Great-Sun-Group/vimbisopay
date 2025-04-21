import 'package:flutter/foundation.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

/// Utility class for tracking app crashes.
///
/// This class provides methods for tracking app crashes using the analytics service.
class CrashTracker {
  /// Tracks an app crash.
  ///
  /// [exception] is the exception that caused the crash.
  /// [stackTrace] is the stack trace of the crash.
  /// [parameters] is a map of additional parameters associated with the crash.
  static void trackCrash({
    required dynamic exception,
    required StackTrace stackTrace,
    Map<String, dynamic> parameters = const {},
  }) {
    try {
      // Log the crash first
      Logger.error('App crash', exception, stackTrace);
      
      // Track the crash with analytics
      final analyticsService = ServiceLocator.analyticsService;
      analyticsService.trackCrash(
        exception: exception,
        stackTrace: stackTrace,
        parameters: parameters,
      );
    } catch (e) {
      Logger.error('Failed to track crash', e);
    }
  }

  /// Sets up a global error handler to track uncaught exceptions.
  ///
  /// This method should be called in the main function to set up a global error handler
  /// that tracks all uncaught exceptions.
  static void setupGlobalErrorHandler() {
    // Set up Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      try {
        // Log the error first
        Logger.error(
          'Uncaught Flutter error',
          details.exception,
          details.stack ?? StackTrace.current,
        );
        
        // Track the error with analytics
        trackCrash(
          exception: details.exception,
          stackTrace: details.stack ?? StackTrace.current,
          parameters: {
            'context': details.context?.toString() ?? 'unknown',
            'library': details.library ?? 'unknown',
          },
        );
        
        // Forward to Flutter's original error handler
        FlutterError.presentError(details);
      } catch (e) {
        Logger.error('Error in global error handler', e);
      }
    };
    
    // Set up Dart error handler for errors outside Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      try {
        // Log the error first
        Logger.error('Uncaught Dart error', error, stack);
        
        // Track the error with analytics
        trackCrash(
          exception: error,
          stackTrace: stack,
          parameters: {
            'source': 'dart_platform_dispatcher',
          },
        );
      } catch (e) {
        Logger.error('Error in platform dispatcher error handler', e);
      }
      
      // Return true to indicate that the error has been handled
      return true;
    };
  }

  /// Runs a function and tracks any exceptions that occur.
  ///
  /// [function] is the function to run.
  /// [parameters] is a map of additional parameters associated with the crash.
  ///
  /// Returns the result of the function if it completes successfully.
  /// If an exception occurs, it is tracked and then rethrown.
  static T runAndTrackExceptions<T>(
    T Function() function, {
    Map<String, dynamic> parameters = const {},
  }) {
    try {
      return function();
    } catch (e, stackTrace) {
      trackCrash(
        exception: e,
        stackTrace: stackTrace,
        parameters: {
          'source': 'tracked_function',
          ...parameters,
        },
      );
      rethrow;
    }
  }

  /// Runs an async function and tracks any exceptions that occur.
  ///
  /// [function] is the async function to run.
  /// [parameters] is a map of additional parameters associated with the crash.
  ///
  /// Returns a Future that completes with the result of the function if it completes successfully.
  /// If an exception occurs, it is tracked and then rethrown.
  static Future<T> runAndTrackAsyncExceptions<T>(
    Future<T> Function() function, {
    Map<String, dynamic> parameters = const {},
  }) async {
    try {
      return await function();
    } catch (e, stackTrace) {
      trackCrash(
        exception: e,
        stackTrace: stackTrace,
        parameters: {
          'source': 'tracked_async_function',
          ...parameters,
        },
      );
      rethrow;
    }
  }
}
