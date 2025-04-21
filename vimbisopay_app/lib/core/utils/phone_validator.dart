class PhoneValidator {
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    // Remove any non-digit characters before validation
    final String digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    
    // Validate country code and length
    if (!RegExp(r'^[0-9]{3}[0-9]+$').hasMatch(digitsOnly)) {
      // Return an empty string instead of an error message
      // This will still make the validation fail but won't show a message
      return '';
    }
    if (digitsOnly.length < 10) {
      // Return an empty string instead of an error message
      // This will still make the validation fail but won't show a message
      return '';
    }
    return null;
  }
}
