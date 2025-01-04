class PhoneValidator {
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    // Remove any non-digit characters before validation
    final String digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    
    if (!RegExp(r'^[0-9]{3}[0-9]+$').hasMatch(digitsOnly)) {
      return 'Start with country code (e.g. 263 or 353)';
    }
    if (digitsOnly.length < 10) {
      return 'Phone number is too short';
    }
    return null;
  }
}
