import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

/// Utility class for safe navigation.
///
/// This class provides methods for navigating between screens while respecting
/// the app state, such as whether the update screen is currently showing.
class NavigationUtils {
  /// Navigates to a named route only if the update screen is not showing.
  ///
  /// Returns true if navigation was performed, false if it was prevented.
  static Future<bool> safeNavigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      Logger.state('Navigation to $routeName prevented while update screen is showing');
      return false;
    }
    
    await Navigator.of(context).pushNamed(routeName, arguments: arguments);
    return true;
  }
  
  /// Replaces the current route with a named route only if the update screen is not showing.
  ///
  /// Returns true if navigation was performed, false if it was prevented.
  static Future<bool> safeNavigateReplacementTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      Logger.state('Navigation replacement to $routeName prevented while update screen is showing');
      return false;
    }
    
    await Navigator.of(context).pushReplacementNamed(routeName, arguments: arguments);
    return true;
  }
  
  /// Pops the current route and navigates to a named route only if the update screen is not showing.
  ///
  /// Returns true if navigation was performed, false if it was prevented.
  static Future<bool> safeNavigateAndRemoveUntil(
    BuildContext context,
    String routeName,
    RoutePredicate predicate, {
    Object? arguments,
  }) async {
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      Logger.state('Navigation and remove until $routeName prevented while update screen is showing');
      return false;
    }
    
    await Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      predicate,
      arguments: arguments,
    );
    return true;
  }
  
  /// Pops the current route only if the update screen is not showing.
  ///
  /// Returns true if navigation was performed, false if it was prevented.
  static bool safePop(BuildContext context, [dynamic result]) {
    if (ServiceLocator.appStateManager.isUpdateScreenShowing) {
      Logger.state('Pop prevented while update screen is showing');
      return false;
    }
    
    Navigator.of(context).pop(result);
    return true;
  }
}
