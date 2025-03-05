import 'package:vimbisopay_app/core/utils/logger.dart';

class PinValidator {
  static const int _minLength = 4;
  static const int _maxLength = 4;
  static const int _minUniqueDigits = 2;

  // Common PINs to block
  static const Set<String> _commonPins = {
    '0000', '1111', '2222', '3333', '4444',
    '5555', '6666', '7777', '8888', '9999',
    '1234', '4321', '1212', '2121', '0123',
  };

  static String? validatePin(String pin) {
    Logger.data('[PIN_VALIDATOR] Validating PIN');

    // Check length
    if (pin.length < _minLength || pin.length > _maxLength) {
      return 'PIN must be $_minLength digits';
    }

    // Check if all characters are digits
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      return 'PIN must contain only digits';
    }

    // Check for sequential numbers
    if (_isSequential(pin)) {
      return 'PIN cannot be sequential numbers';
    }

    // Check for common PINs
    if (_commonPins.contains(pin)) {
      return 'This PIN is too common. Please choose a more secure PIN';
    }

    // Check unique digits
    final uniqueDigits = pin.split('').toSet().length;
    if (uniqueDigits < _minUniqueDigits) {
      return 'PIN must contain at least $_minUniqueDigits different digits';
    }

    Logger.data('[PIN_VALIDATOR] PIN validation passed');
    return null;
  }

  static bool _isSequential(String pin) {
    // Convert pin to list of integers
    final digits = pin.split('').map(int.parse).toList();
    
    // Check ascending sequence
    bool isAscending = true;
    // Check descending sequence
    bool isDescending = true;
    
    for (int i = 1; i < digits.length; i++) {
      if (digits[i] != digits[i - 1] + 1) {
        isAscending = false;
      }
      if (digits[i] != digits[i - 1] - 1) {
        isDescending = false;
      }
    }
    
    return isAscending || isDescending;
  }

  static String getRequirementsText() {
    return '''
• Must be $_minLength digits
• Must contain at least $_minUniqueDigits different digits
• Cannot be sequential numbers (e.g. 1234)
• Cannot be repeated digits (e.g. 1111)
• Cannot be a commonly used PIN
''';
  }
}
