import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/error/failures.dart';

/// Utility class to translate technical error messages into user-friendly ones
class ErrorTranslator {
  /// Translates network-related error messages into user-friendly ones
  static String getNetworkErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    Logger.data('Translating network error: $errorString');
    
    if (errorString.contains('socketexception') || 
        errorString.contains('failed host lookup')) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    }
    
    if (errorString.contains('timeout')) {
      return 'The connection timed out. Please check your internet speed and try again.';
    }
    
    if (errorString.contains('certificate')) {
      return 'There was a security issue connecting to our servers. Please try again later.';
    }
    
    if (errorString.contains('network is unreachable') ||
        errorString.contains('network error')) {
      return 'Your device cannot reach the network. Please check your internet connection.';
    }
    
    if (errorString.contains('connection refused')) {
      return 'The server refused the connection. Please try again later.';
    }
    
    // Default network error message
    return 'A network error occurred. Please check your connection and try again.';
  }
  
  /// Translates server-related error messages into user-friendly ones
  static String getServerErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    Logger.data('Translating server error: $errorString');
    
    if (errorString.contains('500') || 
        errorString.contains('internal server error')) {
      return 'Our servers are experiencing issues. Please try again later.';
    }
    
    if (errorString.contains('503') || 
        errorString.contains('service unavailable')) {
      return 'The service is temporarily unavailable. Please try again later.';
    }
    
    if (errorString.contains('404') || 
        errorString.contains('not found')) {
      return 'The requested resource could not be found. Please try again later.';
    }
    
    if (errorString.contains('429') || 
        errorString.contains('too many requests')) {
      return 'You\'ve made too many requests. Please wait a moment and try again.';
    }
    
    if (errorString.contains('daily limit') || 
        errorString.contains('try again tomorrow')) {
      return 'You have reached the daily limit for this operation. Please try again tomorrow.';
    }
    
    // Default server error message
    return 'Our servers are experiencing issues. Please try again later.';
  }
  
  /// Translates authentication-related error messages into user-friendly ones
  static String getAuthErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    Logger.data('Translating auth error: $errorString');
    
    if (errorString.contains('unauthorized') || 
        errorString.contains('401')) {
      return 'Your session has expired. Please log in again.';
    }
    
    if (errorString.contains('forbidden') || 
        errorString.contains('403')) {
      return 'You don\'t have permission to access this resource.';
    }
    
    if (errorString.contains('invalid credentials') || 
        errorString.contains('incorrect password')) {
      return 'The username or password you entered is incorrect.';
    }
    
    // Default auth error message
    return 'Authentication failed. Please log in again.';
  }
  
  /// Returns a generic error message when the error type is unknown
  static String getGenericErrorMessage() {
    return 'Something went wrong. Please try again.';
  }
  
  /// Checks if the error is related to daily OTP limit
  static bool isDailyLimitError(dynamic error) {
    if (error is InfrastructureFailure && error.message != null) {
      final message = error.message!.toLowerCase();
      return message.contains('daily limit') || message.contains('try again tomorrow');
    }
    
    // Also check the error string itself
    final errorString = error.toString().toLowerCase();
    return errorString.contains('daily limit') || errorString.contains('try again tomorrow');
  }
  
  /// Returns the standard daily limit error message
  static String getDailyLimitErrorMessage() {
    return 'You have reached the daily limit for OTP requests. Please try again tomorrow.';
  }

  /// Determines the most appropriate error message based on the error type
  static String translateError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Check for daily limit errors first (highest priority)
    if (isDailyLimitError(error)) {
      return getDailyLimitErrorMessage();
    }
    
    // Check for network errors
    if (errorString.contains('socketexception') || 
        errorString.contains('failed host lookup') ||
        errorString.contains('timeout') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return getNetworkErrorMessage(error);
    }
    
    // Check for server errors
    if (errorString.contains('500') || 
        errorString.contains('503') ||
        errorString.contains('404') ||
        errorString.contains('429') ||
        errorString.contains('server')) {
      return getServerErrorMessage(error);
    }
    
    // Check for auth errors
    if (errorString.contains('401') || 
        errorString.contains('403') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden') ||
        errorString.contains('credentials')) {
      return getAuthErrorMessage(error);
    }
    
    // Default to generic error message
    return getGenericErrorMessage();
  }
}
