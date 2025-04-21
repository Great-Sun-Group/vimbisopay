import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

/// Utility class for tracking button taps.
///
/// This class provides methods for tracking button taps using the analytics service.
class ButtonTracker {
  /// Tracks a button tap.
  ///
  /// [buttonId] is the identifier of the button being tapped.
  /// [screenName] is the name of the screen where the button is located.
  /// [parameters] is a map of additional parameters associated with the button tap.
  static void trackButtonTap(
    String buttonId, {
    required String screenName,
    Map<String, dynamic> parameters = const {},
  }) {
    try {
      final analyticsService = ServiceLocator.analyticsService;
      analyticsService.trackButtonTap(
        buttonId,
        screenName: screenName,
        parameters: parameters,
      );
    } catch (e) {
      Logger.error('Failed to track button tap', e);
    }
  }

  /// Creates a callback function that tracks a button tap and then executes the original callback.
  ///
  /// [buttonId] is the identifier of the button being tapped.
  /// [screenName] is the name of the screen where the button is located.
  /// [parameters] is a map of additional parameters associated with the button tap.
  /// [callback] is the original callback function to execute after tracking the button tap.
  ///
  /// Returns a new callback function that tracks the button tap and then executes the original callback.
  static void Function()? trackButtonTapWithCallback(
    String buttonId, {
    required String screenName,
    Map<String, dynamic> parameters = const {},
    void Function()? callback,
  }) {
    if (callback == null) {
      return () {
        trackButtonTap(buttonId, screenName: screenName, parameters: parameters);
      };
    }

    return () {
      trackButtonTap(buttonId, screenName: screenName, parameters: parameters);
      callback();
    };
  }

  /// Creates a callback function that tracks a button tap and then executes the original callback with a value.
  ///
  /// [buttonId] is the identifier of the button being tapped.
  /// [screenName] is the name of the screen where the button is located.
  /// [parameters] is a map of additional parameters associated with the button tap.
  /// [callback] is the original callback function to execute after tracking the button tap.
  ///
  /// Returns a new callback function that tracks the button tap and then executes the original callback with a value.
  static void Function(T)? trackButtonTapWithValueCallback<T>(
    String buttonId, {
    required String screenName,
    Map<String, dynamic> parameters = const {},
    void Function(T)? callback,
  }) {
    if (callback == null) {
      return (T value) {
        trackButtonTap(
          buttonId,
          screenName: screenName,
          parameters: {
            ...parameters,
            'value': value.toString(),
          },
        );
      };
    }

    return (T value) {
      trackButtonTap(
        buttonId,
        screenName: screenName,
        parameters: {
          ...parameters,
          'value': value.toString(),
        },
      );
      callback(value);
    };
  }
}
