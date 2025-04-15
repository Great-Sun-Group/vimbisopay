import 'package:vimbisopay_app/core/utils/logger.dart';

/// Manages global application state.
///
/// This service tracks various states of the application, such as whether
/// certain screens are currently showing, to coordinate behavior across
/// different parts of the app.
class AppStateManager {
  bool _isUpdateScreenShowing = false;
  
  /// Returns whether the app update screen is currently showing.
  bool get isUpdateScreenShowing => _isUpdateScreenShowing;
  
  /// Sets whether the app update screen is currently showing.
  ///
  /// This is used to prevent navigation when the update screen is displayed.
  void setUpdateScreenShowing(bool value) {
    Logger.state('Update screen showing state changed to: $value');
    _isUpdateScreenShowing = value;
  }
}
