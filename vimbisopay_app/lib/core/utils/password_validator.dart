import 'package:vimbisopay_app/core/utils/logger.dart';

class PasswordValidator {
  static const int MAX_LENGTH = 128;
  static const int MIN_LENGTH = 12;
  
  static ({bool isValid, String? error}) validatePassword(String password) {
    Logger.data('Validating password');
    
    if (password.isEmpty) {
      return (isValid: false, error: 'Password is required');
    }

    if (password.length > MAX_LENGTH) {
      return (isValid: false, error: 'Password must be less than 128 characters');
    }
    
    if (password.length < MIN_LENGTH) {
      return (isValid: false, error: 'Password must be at least 12 characters');
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return (isValid: false, error: 'Password must contain uppercase letters');
    }
    
    if (!password.contains(RegExp(r'[a-z]'))) {
      return (isValid: false, error: 'Password must contain lowercase letters');
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      return (isValid: false, error: 'Password must contain numbers');
    }
    
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return (isValid: false, error: 'Password must contain special characters');
    }
    
    Logger.data('Password validation successful');
    return (isValid: true, error: null);
  }

  static String getRequirementsText() {
    return '''
Password requirements:
• 12-128 characters
• Uppercase letters (A-Z)
• Lowercase letters (a-z)
• Numbers (0-9)
• Special characters (!@#\$%^&*(),.?":{}|<>)
    ''';
  }
}
