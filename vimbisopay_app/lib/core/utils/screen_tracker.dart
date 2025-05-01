import 'package:flutter/widgets.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

/// Utility class for tracking screen views.
///
/// This class provides methods for tracking screen views using the analytics service.
class ScreenTracker {
  /// Tracks a screen view.
  ///
  /// [screenName] is the name of the screen being viewed.
  /// [parameters] is a map of additional parameters associated with the screen view.
  static void trackScreenView(
    String screenName, {
    Map<String, dynamic> parameters = const {},
  }) {
    try {
      final analyticsService = ServiceLocator.analyticsService;
      analyticsService.trackScreenView(screenName, parameters: parameters);
    } catch (e) {
      Logger.error('Failed to track screen view', e);
    }
  }
}

/// Mixin for tracking screen views in StatefulWidget classes.
///
/// This mixin automatically tracks screen views when the widget is initialized.
/// To use this mixin, add it to your StatefulWidget's State class and override
/// the [screenName] and [screenParameters] getters.
mixin ScreenViewTrackerMixin<T extends StatefulWidget> on State<T> {
  /// The name of the screen to track.
  String get screenName;

  /// Additional parameters to include with the screen view.
  Map<String, dynamic> get screenParameters => {};

  @override
  void initState() {
    super.initState();
    
    // Track screen view after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScreenTracker.trackScreenView(screenName, parameters: screenParameters);
      }
    });
  }
}
