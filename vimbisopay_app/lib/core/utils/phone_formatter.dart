import 'package:flutter/services.dart';
import 'dart:math' show min;

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove any existing formatting
    String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    // Apply formatting
    String formatted = _formatInternationalNumber(digitsOnly);

    // Calculate the new cursor position
    int selectionIndex = formatted.length;
    if (newValue.selection.start < newValue.text.length) {
      selectionIndex = newValue.selection.start;
      // Adjust cursor position based on added spaces and + prefix
      int spacesBeforeCursor = formatted.substring(0, selectionIndex + 1).split(' ').length - 1;
      selectionIndex += spacesBeforeCursor + 1; // +1 for the '+' prefix
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }

  String _formatInternationalNumber(String digits) {
    if (digits.isEmpty) return '';

    final buffer = StringBuffer('+');
    
    // Format first 12 digits with spaces
    int formattedLength = min(12, digits.length);
    for (int i = 0; i < formattedLength; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }
    
    // Add remaining digits without spaces
    if (digits.length > 12) {
      buffer.write(digits.substring(12));
    }
    
    return buffer.toString();
  }
}
