import 'package:flutter/material.dart';

abstract class AppColors {
  // Brand Colors - High Contrast
  static const Color primary = Color(0xFFFBB016);      // Bright Orange - More vibrant
  static const Color secondary = Color(0xFF04A0B2);    // Bright Teal - More vibrant
  static const Color accent = Color(0xFFB17B0F);       // Deep Orange - For depth
  
  // Text Colors - High Contrast
  static const Color textPrimary = Color(0xFFFFFFFF);  // Pure White - For maximum readability
  static const Color textSecondary = Color(0xFFE3E3E3);// Light Gray - For secondary text
  
  // Background Colors - Dark Theme
  static const Color background = Color(0xFF000000);   // Pure Black - Main background
  static const Color surface = Color(0xFF06151F);      // Dark Blue-Black - Secondary background
  
  // Status Colors - High Visibility
  static const Color success = Color(0xFF4CAF50);      // Bright Green
  static const Color error = Color(0xFF9E0202);        // Deep Red
  static const Color warning = Color(0xFFFFA000);      // Bright Orange
  static const Color info = Color(0xFF2196F3);         // Bright Blue

  // Overlay Colors
  static const Color overlay = Color(0x80000000);      // Semi-transparent black for overlays
  static const Color highlightOverlay = Color(0x1AFFFFFF); // Subtle white for highlights
}
