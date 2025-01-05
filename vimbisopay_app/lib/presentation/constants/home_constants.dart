import 'package:flutter/material.dart';

class HomeConstants {
  static const int ledgerPageSize = 20;
  static const double smallScreenAccountCardHeight = 0.45;
  
  // Get constraints for account card
  static BoxConstraints getAccountCardConstraints(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // For smaller screens (< 700px), use 45% height
    // For larger screens, use min/max constraints
    return screenHeight < 700 
      ? BoxConstraints(maxHeight: screenHeight * smallScreenAccountCardHeight)
      : BoxConstraints(
          minHeight: 280.0,  // Minimum height to ensure content fits
          maxHeight: screenHeight * 0.35  // Maximum 35% of screen height
        );
  }
  static const double appBarHeight = 90.0;
  static const double avatarSize = 45.0;
  
  // Button dimensions
  static const double actionButtonSize = 50.0;
  static const double actionButtonIconSize = 24.0;
  static const double actionButtonTextSize = 10.0;
  
  // Padding and spacing
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double tinyPadding = 4.0;
  
  // Text sizes
  static const double headingTextSize = 24.0;
  static const double subheadingTextSize = 16.0;
  static const double bodyTextSize = 14.0;
  static const double captionTextSize = 12.0;
  
  // Border radius
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 20.0;
}
