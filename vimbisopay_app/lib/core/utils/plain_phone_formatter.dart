import 'package:flutter/services.dart';

class PlainPhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only allow digits
    final String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    // No formatting, just return digits
    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
  }
}
