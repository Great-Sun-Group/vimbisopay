import 'package:flutter/material.dart';

abstract class AppColors {
  // ======== BASE COLOR PALETTE ========
  
  // Primary Brand - Green Palette
  static const Color greenPrimary = Color(0xFF044D62);  // Main GREEN color
  static const Color greenDark1 = Color(0xFF222C34);    // Dark shade 1
  static const Color greenDark2 = Color(0xFF223B41);    // Dark shade 2
  static const Color greenMain = Color(0xFF04A0B2);     // Bright teal
  static const Color greenLight1 = Color(0xFF69E5F3);   // Light shade 1
  static const Color greenLight2 = Color(0xFFD5F8FC);   // Light shade 2
  
  // Secondary Brand - Yellow Palette
  static const Color yellowPrimary = Color(0xFFFB8C16); // Main YELLOW color
  static const Color yellowDark1 = Color(0xFF6A4700);   // Dark shade 1
  static const Color yellowDark2 = Color(0xFFC1B81B);   // Dark shade 2
  static const Color yellowMain = Color(0xFFFBB016);    // Bright yellow
  static const Color yellowLight1 = Color(0xFFF4CD7E);  // Light shade 1
  static const Color yellowLight2 = Color(0xFFFECC6);   // Light shade 2
  
  // Shades - Dark Blue Palette
  static const Color darkBluePrimary = Color(0xFF04151F); // Main DARK BLUE color
  static const Color darkBlueDark1 = Color(0xFF060E12);   // Dark shade 1
  static const Color darkBlueDark2 = Color(0xFF06151F);   // Dark shade 2
  static const Color darkBlueMedium = Color(0xFF2E4A5C);  // Medium shade
  static const Color darkBlueLight1 = Color(0xFF99A7B0);  // Light shade 1
  static const Color darkBlueLight2 = Color(0xFFE7E9EB);  // Light shade 2
  
  // Text Color
  static const Color textGray = Color(0xFF616465);      // GRAY for text
  
  // Basic Colors
  static const Color black = Color(0xFF000000);         // BLACK
  static const Color black45 = Color(0x73000000);       // BLACK with 45% opacity
  static const Color white = Color(0xFFFFFFFF);         // WHITE
  static const Color red = Color(0xFFFF0000);           // RED
  static const Color darkRed = Color(0xFFB71C1C);       // DARK RED
  static const Color green = Color(0xFF4CAF50);         // GREEN (same as success)
  static const Color transparent = Colors.transparent;  // TRANSPARENT
  static const Color amber = Color(0xFFFFC107);         // AMBER color
  static const Color grey = Color(0xFF9E9E9E);          // GREY
  static const Color grey200 = Color(0xFFEEEEEE);       // GREY 200
  static const Color grey300 = Color(0xFFE0E0E0);       // GREY 300
  static const Color techAzure = Color(0xFF0078D7);     // Microsoft Tech Azure Blue
  
  // ======== SEMANTIC COLOR DEFINITIONS ========
  // These map the base colors to their functional uses in the app
  
  // Brand Colors
  static const Color primary = yellowMain;              // Primary brand color
  static const Color secondary = greenMain;             // Secondary brand color
  static const Color accent = yellowDark2;              // Accent color for emphasis
  
  // Background Colors
  static const Color background = darkBluePrimary;      // Main background
  static const Color surface = darkBlueDark2;           // Cards, dialogs, surfaces
  
  // Text Colors
  static const Color textPrimary = white;               // Primary text
  static const Color textSecondary = darkBlueLight1;    // Secondary text
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);       // Success messages/actions
  static const Color error = Color(0xFF9E0202);         // Error messages/actions
  static const Color warning = yellowPrimary;           // Warning messages/actions
  static const Color info = greenLight1;                // Information messages/actions
  
  // Overlay Colors
  static const Color overlay = Color(0x80000000);       // Semi-transparent overlay
  static const Color highlightOverlay = Color(0x1AFFFFFF); // Highlight overlay
  static const Color barrierColor = Color(0x42000000);  // Dialog barrier color (equivalent to Colors.black26)
  
  // Additional Colors for Marketplace
  static const Color successGreen = Color(0xFF4CAF50); // Same as success, used in marketplace
  static const Color errorRed = Color(0xFFFF0000);     // Bright red used in marketplace
}
