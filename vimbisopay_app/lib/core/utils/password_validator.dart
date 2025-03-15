class PasswordValidationResult {
  final bool isValid;
  final String? error;

  const PasswordValidationResult({
    required this.isValid,
    this.error,
  });
}

class PasswordValidator {
  static String getRequirementsText() {
    return '• At least 8 characters\n'
           '• At least one uppercase letter\n'
           '• At least one lowercase letter\n'
           '• At least one number\n'
           '• At least one special character\n';
  }

  static PasswordValidationResult validatePassword(String password, [bool showRequirements = false]) {
    if (password.isEmpty) {
      return const PasswordValidationResult(
        isValid: false,
        error: 'Password is required',
      );
    }

    if (password.length < 8) {
      return const PasswordValidationResult(
        isValid: false,
        error: 'Password must be at least 8 characters long',
      );
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      return const PasswordValidationResult(
        isValid: false,
        error: 'Password must contain at least one uppercase letter',
      );
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      return const PasswordValidationResult(
        isValid: false,
        error: 'Password must contain at least one lowercase letter',
      );
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      return const PasswordValidationResult(
        isValid: false,
        error: 'Password must contain at least one number',
      );
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>[\]]'))) {
      return const PasswordValidationResult(
        isValid: false,
        error: 'Password must contain at least one special character',
      );
    }

    return const PasswordValidationResult(isValid: true);
  }

  static bool isValid(String password) {
    final result = validatePassword(password);
    return result.isValid;
  }

  static double calculateStrength(String password) {
    if (password.isEmpty) return 0.0;
    
    double strength = 0.0;
    
    // Length contribution (up to 0.3)
    strength += (password.length / 16).clamp(0.0, 0.3);
    
    // Character variety contribution (up to 0.4)
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.1;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.1;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.1;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>[\]]'))) strength += 0.1;
    
    // Pattern variety contribution (up to 0.3)
    final hasAlternatingTypes = password.contains(
      RegExp(r'(?:[a-z][A-Z])|(?:[A-Z][a-z])|(?:\d[a-zA-Z])|(?:[a-zA-Z]\d)')
    );
    if (hasAlternatingTypes) strength += 0.15;
    
    final hasMultipleSpecialChars = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>[\]].*[!@#$%^&*(),.?":{}|<>[\]]')
    );
    if (hasMultipleSpecialChars) strength += 0.15;
    
    return strength.clamp(0.0, 1.0);
  }
}
